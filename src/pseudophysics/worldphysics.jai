is_cell_solid :: (x : s32, y : s32, z : s32) -> bool {
	world := get_current_world();
	if !world.valid then return false;
	
    key := world_to_chunk_coord(x, y, z);
	chunk := table_find_pointer(*world.world.chunks, key);
    if !chunk then return false;

    lx, ly, lz := world_to_local(x, y, z);
	return chunk_get_occupancy_mask_at(chunk, lx, ly, lz) != .FREE;
}

is_trile_collision :: (fx: float, fy: float, fz: float) -> bool {
	x := cast(s32)floor(fx);
	y := cast(s32)floor(fy);
	z := cast(s32)floor(fz);
	return is_cell_solid(x, y, z);
}

// A little bit of leeway into collisions so we aren't jittering
SKIN :: 0.001;

body_overlaps_solid :: (body : *Physics_Body) -> bool {
	max := body.position + body.half_extents;
	min := body.position - body.half_extents;

	min_x := cast(s32)floor(min.x + SKIN);
	min_y := cast(s32)floor(min.y + SKIN);
	min_z := cast(s32)floor(min.z + SKIN);
	max_x := cast(s32)floor(max.x - SKIN);
	max_y := cast(s32)floor(max.y - SKIN);
	max_z := cast(s32)floor(max.z - SKIN);

	for x : min_x..max_x {
		for y : min_y..max_y {
			for z : min_z..max_z {
				if is_cell_solid(x,y,z) {
					return true;
				}
			}
		}
	}
	return false;
} 
