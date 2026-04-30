fill_uniform_with_engine_data :: (uniform: *$A, enginedata: *$B) {
    generate_copy_code :: () -> string {
        builder : String_Builder;
        ti := type_info(A);
        for ti.members {
            if it.name == "_" then continue; // skip padding
            if it.type == type_info(Vector3) then print_to_builder(*builder, "uniform.% = enginedata.%.component;\n", it.name, it.name);
            else print_to_builder(*builder, "uniform.% = enginedata.%;\n", it.name, it.name);
        }
        return builder_to_string(*builder);
    }
    #insert #run,stallable generate_copy_code();
}

Gathered_Positions :: struct {
    name:      string;
    chunk_key: Chunk_Key;
    positions: [..]Vector4;
}

Gathered_Rdm_Position :: struct {
    name:     string;
    position: Vector4;
}

extract_frustum_planes :: (mvp: Matrix4) -> [6]Vector4 {
    planes : [6]Vector4;
    m := mvp;
    planes[0] = .{m._14+m._11, m._24+m._21, m._34+m._31, m._44+m._41}; // left
    planes[1] = .{m._14-m._11, m._24-m._21, m._34-m._31, m._44-m._41}; // right
    planes[2] = .{m._14+m._12, m._24+m._22, m._34+m._32, m._44+m._42}; // bottom
    planes[3] = .{m._14-m._12, m._24-m._22, m._34-m._32, m._44-m._42}; // top
    planes[4] = .{m._14+m._13, m._24+m._23, m._34+m._33, m._44+m._43}; // near
    planes[5] = .{m._14-m._13, m._24-m._23, m._34-m._33, m._44-m._43}; // far
    return planes;
}

aabb_in_frustum :: (planes: [6]Vector4, bmin: Vector3, bmax: Vector3) -> bool {
    for plane: planes {
        px := ifx plane.x >= 0 then bmax.x else bmin.x;
        py := ifx plane.y >= 0 then bmax.y else bmin.y;
        pz := ifx plane.z >= 0 then bmax.z else bmin.z;
        if plane.x*px + plane.y*py + plane.z*pz + plane.w < 0  return false;
    }
    return true;
}

LOD_NEAR_DIST :: 40.0;
LOD_FAR_DIST  :: 80.0;

// 3-band LOD selection: instances closer than LOD_DISTANCES[i] use LOD level i.
//   i = 0 → full detail
//   i = 1 → 4^3 cube grid
//   i = 2 → 2^3 cube grid
//   beyond LOD_DISTANCES[2] → culled.
LOD_DISTANCES :: float.[50.0, 100.0, 200.0];
FOG_START     :: 60.0;
FOG_END       :: 195.0;

create_world_rendering_tasks :: (world: *World, camera: Camera, plane_height: float = 0) {
    create_sky_rendering_task(*world.conf);
    create_set_light_rendering_task(*world.conf);

    cam_mvp    := create_viewproj(*camera);
    shadow_mvp := create_shadow_viewproj(*camera, *world.conf);
    cam_planes    := extract_frustum_planes(cam_mvp);
    shadow_planes := extract_frustum_planes(shadow_mvp);

    reflect_cam := camera;
    reflect_cam.position   *= .{1, -1, 1};
    reflect_cam.position.y += plane_height * 2;
    reflect_cam.target     *= .{1, -1, 1};
    reflect_cam.target.y   += plane_height * 2;
    reflect_mvp    := create_viewproj(*reflect_cam);
    reflect_planes := extract_frustum_planes(reflect_mvp);

    // Gather positions for camera-visible instances (all passes) and
    // shadow-only instances (chunks visible from sun but not camera).
    gathered_per_lod : [3][..]Gathered_Positions;
    for i: 0..2  gathered_per_lod[i].allocator = temp;
    shad_gathered : [..]Gathered_Positions;
    shad_gathered.allocator = temp;
    rdm_extra     : [..]Gathered_Positions;   // RDM-flagged instances visible to camera; shadow/gbuffer/reflection use base pipeline
    rdm_extra.allocator = temp;
    rdm_main      : [..]Gathered_Rdm_Position; // one entry per RDM-flagged instance for the main pass
    rdm_main.allocator = temp;

    find_or_create :: (list: *[..]Gathered_Positions, name: string, chunk_key: Chunk_Key) -> *Gathered_Positions {
        for *g: list.* {
            if g.name == name && g.chunk_key == chunk_key  return g;
        }
        array_add(list, .{name = name, chunk_key = chunk_key});
        g := *list.*[list.count - 1];
        g.positions.allocator = temp;
        return g;
    }

    for chunk: world.chunks {
        bmin := Vector3.{chunk.coord.x * 32.0, chunk.coord.y * 32.0, chunk.coord.z * 32.0};
        bmax := bmin + .{32, 32, 32};

        in_cam     := aabb_in_frustum(cam_planes,     bmin, bmax);
        in_reflect := aabb_in_frustum(reflect_planes, bmin, bmax);
        in_shad    := aabb_in_frustum(shadow_planes,  bmin, bmax);
        if !in_cam && !in_reflect && !in_shad  continue;

        for group: chunk.groups {
            for inst, idx: group.instances {
                if idx < group.is_buried.count && group.is_buried[idx]  continue;
                wx, wy, wz := chunk_local_to_world(chunk.coord, inst.x, inst.y, inst.z);
                imin := Vector3.{cast(float)wx, cast(float)wy, cast(float)wz};
                imax := imin + .{1, 1, 1};

                inst_cam     := in_cam     && aabb_in_frustum(cam_planes,     imin, imax);
                inst_reflect := in_reflect && aabb_in_frustum(reflect_planes, imin, imax);
                inst_shad    := in_shad    && aabb_in_frustum(shadow_planes,  imin, imax);
                if !inst_cam && !inst_reflect && !inst_shad  continue;

                dist := length(imin + .{0.5, 0.5, 0.5} - camera.position);

                lod_idx : s32 = -1;
                for i: 0..2 {
                    if dist < LOD_DISTANCES[i] {
                        lod_idx = cast(s32) i;
                        break;
                    }
                }
                if lod_idx < 0  continue; // beyond cull distance

                pos := Vector4.{cast(float)wx, cast(float)wy, cast(float)wz, cast(float)inst.orientation};
                is_rdm := is_rdm_instance_enabled(world, wx, wy, wz);
                if inst_cam || inst_reflect {
                    if is_rdm {
                        target := find_or_create(*rdm_extra, group.trile_name, chunk.coord);
                        array_add(*target.positions, pos);
                        if inst_cam {
                            array_add(*rdm_main, .{name = group.trile_name, position = pos});
                        }
                    } else {
                        target := find_or_create(*gathered_per_lod[lod_idx], group.trile_name, chunk.coord);
                        array_add(*target.positions, pos);
                    }
                } else {
                    target := find_or_create(*shad_gathered, group.trile_name, chunk.coord);
                    array_add(*target.positions, pos);
                }
            }
        }
    }

    for lod_idx: 0..2 {
        for g: gathered_per_lod[lod_idx] {
            if g.positions.count < 1  continue;
            triletask : Rendering_Task_Trile;
            triletask.trile     = g.name;
            triletask.chunk_key = g.chunk_key;
            triletask.positions = g.positions;
            triletask.worldConf = *world.conf;
            triletask.lod_index = cast(s32) lod_idx;
            add_rendering_task(triletask);
        }
    }
    for g: shad_gathered {
        if g.positions.count < 1  continue;
        triletask : Rendering_Task_Trile;
        triletask.trile       = g.name;
        triletask.chunk_key   = g.chunk_key;
        triletask.positions   = g.positions;
        triletask.worldConf   = *world.conf;
        triletask.shadow_only = true;
        add_rendering_task(triletask);
    }
    for g: rdm_extra {
        if g.positions.count < 1  continue;
        triletask : Rendering_Task_Trile;
        triletask.trile     = g.name;
        triletask.chunk_key = g.chunk_key;
        triletask.positions = g.positions;
        triletask.worldConf = *world.conf;
        triletask.skip_main = true;
        add_rendering_task(triletask);
    }
    for r: rdm_main {
        rect, found := rdm_get_atlas_rect(world, cast(s32) r.position.x, cast(s32) r.position.y, cast(s32) r.position.z);
        if !found then continue;
        rdmtask : Rendering_Task_Trile_RDM;
        rdmtask.trile      = r.name;
        rdmtask.position   = r.position;
        rdmtask.atlas_rect = rect;
        rdmtask.worldConf  = *world.conf;
        add_rendering_task(rdmtask);
    }

    create_ground_rendering_task(world);
}

create_sky_rendering_task :: (conf: *World_Config) {
	skytask := Rendering_Task_Sky.{type = .SKY, worldConfig = conf};
	add_rendering_task(skytask);
}

create_set_light_rendering_task :: (conf: *World_Config) {
	lighttask := Rendering_Task_Set_Light.{type = .SET_LIGHT, worldConfig = conf};
	add_rendering_task(lighttask);
}

TRIXEL_IDENTITY : Matrix4 : .{_11=1, _22=1, _33=1, _44=1};

create_trixel_rendering_task :: (trile: *Trile, muls: *[16][16][16]Vector3, world_offset: Vector3 = .{}, brightness: float = 1.0, tile_rotation: Matrix4 = TRIXEL_IDENTITY, is_secondary: bool = false) {
	trixeltask := Rendering_Task_Trixels.{type = .TRIXELS, trile = trile, colMultipliers = muls, world_offset = world_offset, brightness = brightness, tile_rotation = tile_rotation, is_secondary = is_secondary};
	add_rendering_task(trixeltask);
}

create_ground_rendering_task :: (world: *World) {
	groundtask := Rendering_Task_Ground.{type = .GROUND, world = world};
	add_rendering_task(groundtask);
}

create_billboard_rendering_task :: (position: Vector3, animation: *Animation, frame: s32, flipX: bool, flipY: bool, faceDir : Vector3 = .{-100, -100, -100}) {
	billboardtask := Rendering_Task_Billboard.{type = .BILLBOARD, position = position, animation = animation, frame = frame, flipX = flipX, flipY = flipY, faceDir = faceDir };
	add_rendering_task(billboardtask);
}

create_set_cam_rendering_task :: (cam: Camera, planeHeight: float) {
    camtask := Rendering_Task_Set_Camera.{type = .SET_CAMERA, camera = cam, planeHeight = planeHeight};
    add_rendering_task(camtask);
}

get_low_res :: (width: s32, height: s32, max_dimension: s32 = 720) -> (s32, s32) {
    if width == 0 || height == 0 {
        return 0, 0;
    }
    aspect_ratio := cast(float)width / cast(float)height;
    w: s32;
    h: s32;
    if width > height {
        w = max_dimension;
        h = cast(s32)floor(cast(float)w / aspect_ratio);
    } else {
        h = max_dimension;
        w = cast(s32)floor(cast(float)h * aspect_ratio);
    }
       
    return w, h;
}

get_render_size :: () -> (s32, s32) {
	w,h := get_window_size();
	// w, h = get_low_res(w,h, 480);
	return w, h;
}

flip_y_if_plat :: inline (v: Vector2) -> Vector2 {
    return .{v.x, flip_if_plat(v.y)};
}

// Some platforms draw UVs in weird reverse way
// so this function here does the flip on those platforms
// so we don't need to do the platform check in many places.
flip_if_plat :: inline (n: float) -> float {
    #if OS == .MACOS {
        return 1 - n;
    } else {
        return n; 
    }
}
