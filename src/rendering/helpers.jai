create_world_rendering_tasks :: (world: *World) {
	skytask := Rendering_Task_Sky.{type = .SKY, worldConfig = *world.conf};
	add_rendering_task(skytask);
	groundtask := Rendering_Task_Ground.{type = .GROUND, world = world};
	add_rendering_task(groundtask);
    for world.positions {
		triletask := Rendering_Task_Trile.{};
		triletask.trile = it.trileName;
		triletask.positions = it.positions;
		triletask.worldConf = *world.conf;
		add_rendering_task(triletask);
	}
}

create_set_cam_rendering_task :: (cam: Camera) {
    camtask := Rendering_Task_Set_Camera.{type = .SET_CAMERA, camera = cam};
    add_rendering_task(camtask);
}
