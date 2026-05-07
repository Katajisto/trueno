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

aabb_in_frustum :: inline (planes: [6]Vector4, bmin: Vector3, bmax: Vector3) -> bool {
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


shad_gathered    : [..]Gathered_Positions;
rdm_extra        : [..]Gathered_Positions;
rdm_main         : [..]Gathered_Rdm_Position;
gathered_per_lod : [3][..]Gathered_Positions;

Gathered_Positions :: struct {
    trile     : string;
    chunk_key : Chunk_Key;
    positions : [..]Vector4;
}

Gathered_Rdm_Position :: struct {
    name:     string;
    position: Vector4;
}

gathered_chunk_tasks : [..]Gathered_Positions;

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

    for chunk: world.chunks {       
        // Skip chunks that are completely out of view.
        bmin := Vector3.{
            chunk.coord.x * 32.0,
            chunk.coord.y * 32.0,
            chunk.coord.z * 32.0
        };
        bmax := bmin + .{32, 32, 32};
        in_cam     := aabb_in_frustum(cam_planes,     bmin, bmax);
        in_reflect := aabb_in_frustum(reflect_planes, bmin, bmax);
        in_shad    := aabb_in_frustum(shadow_planes,  bmin, bmax);
        vis        := in_cam || in_reflect || in_shad;
        if !vis then continue;

        for group : chunk.groups {
            if group.instances.count < 1 then continue;


            gmin := group.bounding_min;
            gmax := group.bounding_max;
            gavg := group.average_pos;

            gmin += Vector3.{cast(float)chunk.coord.x * 32, cast(float)chunk.coord.y * 32, cast(float)chunk.coord.z * 32};
            gmax += Vector3.{cast(float)chunk.coord.x * 32, cast(float)chunk.coord.y * 32, cast(float)chunk.coord.z * 32};
            gavg += Vector3.{cast(float)chunk.coord.x * 32, cast(float)chunk.coord.y * 32, cast(float)chunk.coord.z * 32};
            in_cam     := aabb_in_frustum(cam_planes,     gmin, gmax);
            in_reflect := aabb_in_frustum(reflect_planes, gmin, gmax);
            in_shad    := aabb_in_frustum(shadow_planes,  gmin, gmax);
            vis        := in_cam || in_reflect || in_shad;

            if !vis then continue;

            diff := gavg - camera.position;
            dist := length(diff);
            lod_index : s32 = 0;
            for lod_dist : LOD_DISTANCES {
                if dist < lod_dist then break;
                lod_index += 1;
            }
            
            task := Rendering_Task_Trile.{
                trile      = group.trile_name,
                chunk_key  = chunk.coord,
                positions  = group.instances,
                worldConf  = *world.conf,
                lod_index = lod_index
            };
            add_rendering_task(task);
        }
        
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
