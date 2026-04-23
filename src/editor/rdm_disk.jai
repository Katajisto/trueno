// RDM disk format helpers shared by the baking tool (tacoma) and the
// sfetch-based streaming loader (rdm_loader.jai).

RDM_File_Header :: struct {
    magic:  u32;
    width:  s32;
    height: s32;
}

RDM_FILE_MAGIC :: u32.[0x4D445254][0]; // "TRDM" as little-endian u32

rdm_global_atlas_filename :: (world_name: string) -> string {
    return sprint("%/worlds/%/rdm_atlas.rdm", GAME_RESOURCES_DIR, world_name);
}

rdm_global_manifest_filename :: (world_name: string) -> string {
    return sprint("%/worlds/%/rdm_manifest.json", GAME_RESOURCES_DIR, world_name);
}

// SH probe grid (2 probes per trile per axis = 64x64x64 per 32x32x32 chunk)

SH_FILE_MAGIC :: u32.[0x44475348][0]; // "SHGD" as little-endian u32
SH_PROBE_N    :: 64;   // probes per axis (2 per trile in a 32-trile chunk)
SH_TEX_W      :: SH_PROBE_N * 3; // 192 — 3 RGBA texels per probe along X

SH_Grid_File_Header :: struct {
    magic:   u32;
    version: u16;
    probe_n: s32;
}

shgrid_filename :: (world_name: string, chunk_key: Chunk_Key) -> string {
    return sprint("%/worlds/%/%_%_%.shgrid", GAME_RESOURCES_DIR, world_name, chunk_key.x, chunk_key.y, chunk_key.z);
}

f32_to_f16 :: (f: float) -> u16 {
    b    := (cast(*u32) *f).*;
    sign := (b >> 31) & 0x1;
    exp  := cast(s32)((b >> 23) & 0xFF) - 127;
    mant := b & 0x7FFFFF;
    if exp >= 16  return cast(u16)((sign << 15) | 0x7C00);  // clamp to inf
    if exp >= -14 return cast(u16)((sign << 15) | (cast(u32)(exp + 15) << 10) | (mant >> 13));
    if exp >= -24 {
        shift := cast(u32)(-exp - 1);
        return cast(u16)((sign << 15) | ((mant | 0x800000) >> shift));
    }
    return cast(u16)(sign << 15);  // underflow → ±0
}
