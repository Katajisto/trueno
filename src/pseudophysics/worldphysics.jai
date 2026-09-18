is_trile_collision :: (fx: float, fy: float, fz: float) -> bool {
	x := cast(s32)fx;
	y := cast(s32)fy;
	z := cast(s32)fz;
	world := get_current_world();
    key := world_to_chunk_coord(x, y, z);
	chunk := table_find_pointer(*world.world.chunks, key);
    if !chunk then return false;

    lx, ly, lz := world_to_local(x, y, z);

	print("% % %\n", lx, ly, lz);

	return chunk.occupancy_mask[lx][ly][lz];
}
