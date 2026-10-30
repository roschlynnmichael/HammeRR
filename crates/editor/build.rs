use std::path::Path;
use std::process::Command;

fn main() {
    #[cfg(target_os = "windows")]
    {
        println!("cargo:rerun-if-changed=icon.ico");
        println!("cargo:rerun-if-changed=app.rc");

        let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
        let out_dir = std::env::var("OUT_DIR").unwrap();
        let res_path = format!("{}/app.res", out_dir);
        let rc_path = format!("{}/app.rc", manifest_dir);

        let candidates = [
            "rc.exe",
            r"C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\rc.exe",
            r"C:\Program Files (x86)\Windows Kits\10\bin\10.0.28000.0\x64\rc.exe",
            r"C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\rc.exe",
        ];

        let mut compiled = false;
        for rc in candidates {
            if let Ok(status) = Command::new(rc)
                .args(&["/fo", &res_path, &rc_path])
                .current_dir(&manifest_dir)
                .status()
            {
                if status.success() {
                    println!("cargo:rustc-link-arg={}", res_path);
                    compiled = true;
                    break;
                }
            }
        }

        if !compiled {
            let fallback_res = format!("{}/app.res", manifest_dir);
            if Path::new(&fallback_res).exists() {
                println!("cargo:rustc-link-arg={}", fallback_res);
            }
        }
    }
}

