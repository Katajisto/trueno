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
