use std::io::{self, Read};
use std::path::{Path, PathBuf};

use regex::Regex;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use source_formats::{
    bsp::{self, Bsp},
    vmf::Vmf,
};

use crate::{CaptureChannel, CaptureEnvironment, CaptureObserver, CaptureReceipt, CaptureRequest};

const CONTROLLER: &str = "\n{\n\"classname\" \"logic_script\"\n\"targetname\" \"__hammerr_capture_controller\"\n\"vscripts\" \"hammerr_capture.nut\"\n\"thinkfunction\" \"HammeRRCaptureThink\"\n}\n";
const MAX_BSP: usize = 128 * 1024 * 1024;

fn invalid(message: impl Into<String>) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message.into())
}

fn dangerous_class(class: &str) -> bool {
    matches!(
        class.to_ascii_lowercase().as_str(),
        "logic_script"
            | "point_servercommand"
            | "point_clientcommand"
            | "point_broadcastclientcommand"
    )
}

fn dangerous_input(input: &str) -> bool {
    let input = input.trim().to_ascii_lowercase();
    input.starts_with("runscript")
        || input.contains("consolecommand")
        || matches!(
            input.as_str(),
            "command" | "callscriptfunction" | "setthinkfunction"
        )
}

pub fn preflight_vmf(vmf: &Vmf) -> io::Result<()> {
    if vmf.world.properties.iter().any(|(key, value)| {
        matches!(
            key.to_ascii_lowercase().as_str(),
            "vscripts" | "thinkfunction"
        ) && !value.trim().is_empty()
    }) {
        return Err(invalid(format!(
            "world:{} cannot participate in private reflection capture: authored scripts are unsupported",
            vmf.world.id
        )));
    }
    for entity in vmf.entities.iter().filter(|e| !e.hidden) {
        let unsafe_property = entity.properties.iter().any(|(key, value)| {
            matches!(
                key.to_ascii_lowercase().as_str(),
                "vscripts" | "thinkfunction"
            ) && !value.trim().is_empty()
        });
        let unsafe_connection = entity
            .connections
            .iter()
            .flatten()
            .any(|connection| connection.fields().nth(1).is_some_and(dangerous_input));
        if dangerous_class(entity.classname().unwrap_or(""))
            || unsafe_property
            || unsafe_connection
            || entity
                .properties
                .get("targetname")
                .is_some_and(|v| v.starts_with("__hammerr_capture_"))
        {
            return Err(invalid(format!(
                "entity:{} cannot participate in private reflection capture: authored scripts or console-command inputs are unsupported",
                entity.id
            )));
        }
    }
    Ok(())
}

pub fn capture_staging_bsp(bytes: &[u8]) -> io::Result<Vec<u8>> {
    capture_staging_bsp_for_channel(bytes, CaptureChannel::Ldr)
}

pub fn capture_staging_bsp_for_channel(bytes: &[u8], channel: CaptureChannel) -> io::Result<Vec<u8>> {
    if bytes.len() > MAX_BSP {
        return Err(invalid("Capture BSP exceeds 128 MiB"));
    }
    let mut bsp = Bsp::parse(bytes)?;
    let entities = bsp.entities()?;
    if entities.len() > 4 * 1024 * 1024 {
        return Err(invalid("Capture entity text exceeds 4 MiB"));
    }
    let executable = Regex::new(r#"(?i)"classname"\s*"(?:logic_script|point_servercommand|point_clientcommand|point_broadcastclientcommand)"|\b(?:runscript\w*|consolecommand|callscriptfunction|setthinkfunction)\b|[,\x1b]command[,\x1b]|__hammerr_capture_"#).map_err(io::Error::other)?;
    let script_fields =
        Regex::new(r#"(?i)"(?:vscripts|thinkfunction)"\s*"([^"]*)""#).map_err(io::Error::other)?;
    if executable.is_match(entities)
        || script_fields
            .captures_iter(entities)
            .any(|capture| !capture[1].trim().is_empty())
    {
        return Err(invalid(
            "Compiled entities contain unsupported authored scripts or console commands; inspect the source entity diagnostics",
        ));
    }
    if channel == CaptureChannel::Hdr
        && [
            bsp::lump::LIGHTING_HDR,
            bsp::lump::WORLDLIGHTS_HDR,
            bsp::lump::LEAF_AMBIENT_LIGHTING_HDR,
        ]
        .iter()
        .any(|&index| bsp.lump(index).data.is_empty())
    {
        return Err(invalid(
            "HDR reflection capture requires complete native HDR lighting, world-light and ambient arrays",
        ));
    }
    let mut entities = entities.to_owned();
    entities.push_str(CONTROLLER);
    bsp.set_entities(&entities);
    for index in [
        bsp::lump::FACES,
        bsp::lump::LIGHTING_HDR,
        bsp::lump::LEAF_AMBIENT_LIGHTING_HDR,
    ] {
        bsp.lumps[index].version = 1;
    }
    let result = bsp.to_bytes();
    if result.len() > MAX_BSP {
        return Err(invalid("Staged capture BSP exceeds 128 MiB"));
    }
    Ok(result)
}

pub fn resolve_environment(environment: &CaptureEnvironment) -> io::Result<CaptureEnvironment> {
    let engine_root = environment.engine_root.canonicalize()?;
    let steam_root = if environment.steam_root.as_os_str().is_empty() {
        engine_root.clone()
    } else {
        environment.steam_root.canonicalize()?
    };
    Ok(CaptureEnvironment {
        engine_root,
        steam_root,
        mounts: environment.mounts.clone(),
    })
}

pub fn validate_environment(environment: &CaptureEnvironment) -> io::Result<()> {
    let root = environment.engine_root.canonicalize()?;
    let has_cstrike = root.join("cstrike_win64.exe").is_file()
        || root.join("cstrike.exe").is_file()
        || root.join("hl2.exe").is_file()
        || root.join("cstrike_linux64").is_file();
    let has_gameinfo = root.join("cstrike").join("gameinfo.txt").is_file() || root.join("cstrike/gameinfo.txt").is_file();
    if !has_cstrike || !has_gameinfo {
        return Err(invalid(
            "Configured native engine root is not a valid CS:S installation",
        ));
    }
    if environment.mounts.len() > 256 {
        return Err(invalid("Native content mount budget exceeded"));
    }
    for mount in &environment.mounts {
        let path = mount.path.canonicalize()?;
        if path
            .to_str()
            .is_none_or(|p| p.contains(['"', '\n', '\r', '\0']))
            || mount.ids.len() > 16
        {
            return Err(invalid("Unsupported native content mount path or IDs"));
        }
    }
    Ok(())
}

pub fn capture(
    request: CaptureRequest,
    observer: &mut dyn CaptureObserver,
) -> io::Result<CaptureReceipt> {
    capture_with_cleanup(request, observer).map_err(|failure| failure.error)
}

pub fn capture_with_cleanup(
    _request: CaptureRequest,
    _observer: &mut dyn CaptureObserver,
) -> Result<CaptureReceipt, crate::CaptureFailure> {
    Err(crate::CaptureFailure {
        error: io::Error::new(
            io::ErrorKind::Unsupported,
            "In-engine reflection capture is currently only supported on Linux (sandboxed bwrap runtime)",
        ),
        cleanup: crate::CleanupDisposition::Confirmed,
    })
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum PplMidrange909Case {
    #[serde(rename = "target-032")]
    Target032,
    #[serde(rename = "reference-032")]
    Reference032,
    #[serde(rename = "target-064")]
    Target064,
    #[serde(rename = "reference-064")]
    Reference064,
    #[serde(rename = "target-096")]
    Target096,
    #[serde(rename = "reference-096")]
    Reference096,
}

pub struct PplMidrange909Request {
    pub case: PplMidrange909Case,
    pub environment: CaptureEnvironment,
    pub bsp: PathBuf,
    pub fixture_game: PathBuf,
    pub observer_library: PathBuf,
    pub artifacts_parent: PathBuf,
}

#[derive(Debug, Serialize)]
pub struct PplMidrange909Receipt {
    pub case: PplMidrange909Case,
    pub artifacts: PathBuf,
    pub elapsed_ms: u64,
    pub verified_controls: bool,
    pub hardware_observed: bool,
    pub preservation_passed: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum PplMips931Case {
    #[serde(rename = "tail-032")]
    Tail032,
    #[serde(rename = "tail-096")]
    Tail096,
    #[serde(rename = "reference-032")]
    Reference032,
    #[serde(rename = "reference-096")]
    Reference096,
    #[serde(rename = "filter-a")]
    FilterA,
    #[serde(rename = "filter-b")]
    FilterB,
    #[serde(rename = "filter-reference-064")]
    FilterReference064,
    #[serde(rename = "filter-reference-096")]
    FilterReference096,
    #[serde(rename = "address-a")]
    AddressA,
    #[serde(rename = "address-b")]
    AddressB,
    #[serde(rename = "address-reference-064")]
    AddressReference064,
    #[serde(rename = "address-reference-096")]
    AddressReference096,
}

pub struct PplMips931Request {
    pub case: PplMips931Case,
    pub environment: CaptureEnvironment,
    pub bsp: PathBuf,
    pub fixture_game: PathBuf,
    pub observer_library: PathBuf,
    pub artifacts_parent: PathBuf,
}

#[derive(Debug, Serialize)]
pub struct PplMips931Receipt {
    pub case: PplMips931Case,
    pub artifacts: PathBuf,
    pub elapsed_ms: u64,
    pub verified_controls: bool,
    pub hardware_observed: bool,
    pub preservation_passed: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum PplSpatial919Case {
    ChartA,
    ChartB,
}

pub struct PplSpatial919Request {
    pub case: PplSpatial919Case,
    pub environment: CaptureEnvironment,
    pub bsp: PathBuf,
    pub fixture_game: PathBuf,
    pub observer_library: PathBuf,
    pub artifacts_parent: PathBuf,
}

#[derive(Debug, Serialize)]
pub struct PplSpatial919Receipt {
    pub case: PplSpatial919Case,
    pub artifacts: PathBuf,
    pub elapsed_ms: u64,
    pub verified_controls: bool,
    pub hardware_observed: bool,
    pub preservation_passed: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum PplUv857Case {
    MissingUv,
    #[serde(rename = "uniform-R")]
    UniformR,
    #[serde(rename = "uniform-B")]
    UniformB,
    #[serde(rename = "uniform-G")]
    UniformG,
    #[serde(rename = "uniform-W")]
    UniformW,
    #[serde(rename = "quadrant-R")]
    QuadrantR,
    #[serde(rename = "quadrant-B")]
    QuadrantB,
    #[serde(rename = "quadrant-G")]
    QuadrantG,
    #[serde(rename = "quadrant-W")]
    QuadrantW,
}

pub struct PplUv857Request {
    pub case: PplUv857Case,
    pub environment: CaptureEnvironment,
    pub bsp: PathBuf,
    pub fixture_game: PathBuf,
    pub observer_library: PathBuf,
    pub artifacts_parent: PathBuf,
}

#[derive(Debug, Serialize)]
pub struct PplUv857Receipt {
    pub case: PplUv857Case,
    pub artifacts: PathBuf,
    pub elapsed_ms: u64,
    pub verified_controls: bool,
    pub hardware_observed: bool,
    pub preservation_passed: bool,
}

pub fn diagnose_ppl_uv857_with_cleanup(
    _request: PplUv857Request,
    _observer: &mut dyn CaptureObserver,
) -> Result<PplUv857Receipt, crate::CaptureFailure> {
    Err(crate::CaptureFailure {
        error: io::Error::new(io::ErrorKind::Unsupported, "Diagnostics require Linux"),
        cleanup: crate::CleanupDisposition::Confirmed,
    })
}

pub fn diagnose_ppl_midrange909_with_cleanup(
    _request: PplMidrange909Request,
    _observer: &mut dyn CaptureObserver,
) -> Result<PplMidrange909Receipt, crate::CaptureFailure> {
    Err(crate::CaptureFailure {
        error: io::Error::new(io::ErrorKind::Unsupported, "Diagnostics require Linux"),
        cleanup: crate::CleanupDisposition::Confirmed,
    })
}

pub fn diagnose_ppl_spatial919_with_cleanup(
    _request: PplSpatial919Request,
    _observer: &mut dyn CaptureObserver,
) -> Result<PplSpatial919Receipt, crate::CaptureFailure> {
    Err(crate::CaptureFailure {
        error: io::Error::new(io::ErrorKind::Unsupported, "Diagnostics require Linux"),
        cleanup: crate::CleanupDisposition::Confirmed,
    })
}

pub fn diagnose_ppl_mips931_with_cleanup(
    _request: PplMips931Request,
    _observer: &mut dyn CaptureObserver,
) -> Result<PplMips931Receipt, crate::CaptureFailure> {
    Err(crate::CaptureFailure {
        error: io::Error::new(io::ErrorKind::Unsupported, "Diagnostics require Linux"),
        cleanup: crate::CleanupDisposition::Confirmed,
    })
}

pub fn worker_entry(_arguments: Vec<std::ffi::OsString>) -> io::Result<()> {
    Err(io::Error::new(
        io::ErrorKind::Unsupported,
        "Native runtime worker is not supported on this platform",
    ))
}

pub fn fingerprint(path: &Path) -> io::Result<String> {
    let mut file = std::fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 64 * 1024];
    loop {
        let count = file.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

