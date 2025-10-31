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

create_world_rendering_tasks :: (world: *World) {
    create_sky_rendering_task(*world.conf);
    create_set_light_rendering_task(*world.conf);
    for world.positions {
        if it.positions.count < 1 then continue;
		triletask := Rendering_Task_Trile.{};
		triletask.trile = it.trileName;
		triletask.positions = it.positions;
		triletask.worldConf = *world.conf;
		add_rendering_task(triletask);
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

create_trixel_rendering_task :: (trile: *Trile, muls: *[16][16][16]Vector3) {
	trixeltask := Rendering_Task_Trixels.{type = .TRIXELS, trile = trile, colMultipliers = muls};
	add_rendering_task(trixeltask);
    
}

create_ground_rendering_task :: (world: *World) {
	groundtask := Rendering_Task_Ground.{type = .GROUND, world = world};
	add_rendering_task(groundtask);
}

create_billboard_rendering_task :: (position: Vector3, animation: *Animation, frame: s32, flipX: bool, flipY: bool) {
	billboardtask := Rendering_Task_Billboard.{type = .BILLBOARD, position = position, animation = animation, frame = frame, flipX = flipX, flipY = flipY };
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
	// wl, hl := get_low_res(w,h, 360);
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
