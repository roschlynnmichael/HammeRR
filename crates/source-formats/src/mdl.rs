use std::ffi::CStr;
use std::io;

pub const MAX_MODEL_BYTES: usize = 64 * 1024 * 1024;
pub const STATIC_PROP_FLAG: u32 = 0x10;
const HEADER_BYTES: usize = 240;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ModelHeader {
    pub checksum: i32,
    pub flags: u32,
    pub hull_mins: [f32; 3],
    pub hull_maxs: [f32; 3],
    pub render_mins: [f32; 3],
    pub render_maxs: [f32; 3],
    pub illumination: [f32; 3],
    pub skins: usize,
}

fn invalid(message: &str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

fn integer(data: &[u8], offset: usize) -> i32 {
    i32::from_le_bytes(data[offset..offset + 4].try_into().unwrap())
}

fn vector(data: &[u8], offset: usize) -> [f32; 3] {
    std::array::from_fn(|i| {
        f32::from_le_bytes(data[offset + i * 4..offset + i * 4 + 4].try_into().unwrap())
    })
}

impl ModelHeader {
    pub fn parse(data: &[u8]) -> io::Result<Self> {
        if data.len() < HEADER_BYTES || data.len() > MAX_MODEL_BYTES || &data[..4] != b"IDST" {
            return Err(invalid("model header size or IDST magic is invalid"));
        }
        let version = integer(data, 4);
        if !(35..=60).contains(&version) {
            return Err(invalid("only Source MDL versions 35 to 60 are supported"));
        }
        let declared = integer(data, 76);
        if declared <= 0 || (declared as usize) > data.len() {
            return Err(invalid("model declared length exceeds file size"));
        }
        let skins = integer(data, 224).clamp(1, 65_535) as usize;
        let mut hull_mins = vector(data, 104);
        let mut hull_maxs = vector(data, 116);
        let mut render_mins = vector(data, 128);
        let mut render_maxs = vector(data, 140);
        for i in 0..3 {
            if !hull_mins[i].is_finite() { hull_mins[i] = -16.0; }
            if !hull_maxs[i].is_finite() { hull_maxs[i] = 16.0; }
            if hull_mins[i] > hull_maxs[i] {
                std::mem::swap(&mut hull_mins[i], &mut hull_maxs[i]);
            }
            if !render_mins[i].is_finite() { render_mins[i] = hull_mins[i]; }
            if !render_maxs[i].is_finite() { render_maxs[i] = hull_maxs[i]; }
            if render_mins[i] > render_maxs[i] {
                std::mem::swap(&mut render_mins[i], &mut render_maxs[i]);
            }
        }
        let mut illumination = vector(data, 92);
        if illumination.iter().any(|v| !v.is_finite()) {
            illumination = [0.0, 0.0, 0.0];
        }
        let result = Self {
            checksum: integer(data, 8),
            flags: integer(data, 152) as u32,
            hull_mins,
            hull_maxs,
            render_mins,
            render_maxs,
            illumination,
            skins,
        };
        Ok(result)
    }

    pub fn is_static_prop(self) -> bool {
        self.flags & STATIC_PROP_FLAG != 0
    }
}

pub fn validate_physics(data: &[u8], checksum: i32) -> io::Result<usize> {
    if data.len() < 16 || data.len() > crate::bsp::MAX_PHYSICS_BYTES {
        return Err(invalid("model physics file size is invalid"));
    }
    let count = integer(data, 8);
    if integer(data, 0) != 16
        || integer(data, 4) != 0
        || integer(data, 12) != checksum
        || !(1..=1024).contains(&count)
    {
        return Err(invalid("model physics header/count/checksum is invalid"));
    }
    let mut payload = &data[16..];
    for _ in 0..count {
        let (size, tail) = payload
            .split_at_checked(4)
            .ok_or_else(|| invalid("model physics solid length is truncated"))?;
        let size = i32::from_le_bytes(size.try_into().unwrap());
        if size < 0 || size as usize > crate::bsp::MAX_COLLISION_BYTES {
            return Err(invalid("model physics solid size is invalid"));
        }
        let (solid, tail) = tail
            .split_at_checked(size as usize)
            .ok_or_else(|| invalid("model physics solid is truncated"))?;
        if !matches!(
            crate::bsp::PhysicsSolid::parse(solid)?.header(),
            crate::bsp::CollisionHeader::Convex { .. }
        ) {
            return Err(invalid("model physics needs a supported convex solid"));
        }
        payload = tail;
    }
    if payload.len() > crate::bsp::MAX_PHYSICS_KEY_BYTES
        || CStr::from_bytes_with_nul(payload).is_err()
    {
        return Err(invalid(
            "model physics keys need bounded, singly terminated text",
        ));
    }
    Ok(count as usize)
}
