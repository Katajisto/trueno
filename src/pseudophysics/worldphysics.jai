is_trile_collision :: (fx: float, fy: float, fz: float) -> bool {
	x := cast(s32)floor(fx);
	y := cast(s32)floor(fy);
	z := cast(s32)floor(fz);
	world := get_current_world();
	if !world.valid then return false;
	
    key := world_to_chunk_coord(x, y, z);
	chunk := table_find_pointer(*world.world.chunks, key);
    if !chunk then return false;

    lx, ly, lz := world_to_local(x, y, z);
	return chunk_get_occupancy_mask_at(chunk, lx, ly, lz) != .FREE;
}
