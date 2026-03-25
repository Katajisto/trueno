// RDM disk format helpers shared by the baking tool (tacoma) and the
// sfetch-based streaming loader (rdm_loader.jai).

RDM_File_Header :: struct {
    magic:  u32;
    width:  s32;
    height: s32;
}

RDM_FILE_MAGIC :: u32.[0x4D445254][0]; // "TRDM" as little-endian u32

rdm_chunk_filename :: (world_name: string, chunk_key: Chunk_Key, suffix: string) -> string {
    return sprint("%/worlds/%/%_%_%.%", GAME_RESOURCES_DIR, world_name, chunk_key.x, chunk_key.y, chunk_key.z, suffix);
}
