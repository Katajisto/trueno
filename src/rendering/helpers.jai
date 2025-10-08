create_world_rendering_tasks :: (world: *World) {
    create_sky_rendering_task(*world.conf);
    create_ground_rendering_task(world);
    for world.positions {
		triletask := Rendering_Task_Trile.{};
		triletask.trile = it.trileName;
		triletask.positions = it.positions;
		triletask.worldConf = *world.conf;
		add_rendering_task(triletask);
	}
}

create_sky_rendering_task :: (conf: *World_Config) {
	skytask := Rendering_Task_Sky.{type = .SKY, worldConfig = conf};
	add_rendering_task(skytask);
}

create_trixel_rendering_task :: (trile: *Trile) {
	trixeltask := Rendering_Task_Trixels.{type = .TRIXELS, trile = trile};
	add_rendering_task(trixeltask);
    
}

create_ground_rendering_task :: (world: *World) {
	groundtask := Rendering_Task_Ground.{type = .GROUND, world = world};
	add_rendering_task(groundtask);
}

create_set_cam_rendering_task :: (cam: Camera) {
    camtask := Rendering_Task_Set_Camera.{type = .SET_CAMERA, camera = cam};
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
	wl, hl := get_low_res(w,h, 360);
	return wl, hl;
}
