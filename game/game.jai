#scope_file

char_pos : Vector3 = .{0.0, 1.5, 0.0};
rotation : float   = 0.0;

cam : Camera = .{
	far = 2000.0,
	near = 1.0,
	target = .{0.0, 4.0, 0.0},
	position = .{3.0, 5.0, 3.0}
};

world : World;

#scope_export
game_init :: () {
	world.ground[500][500] = .GRASS;
	world.ground[500][501] = .GRASS;
	world.ground[500][499] = .GRASS;
	world.ground[499][500] = .GRASS;
	world.ground[500][500] = .GRASS;
	world.ground[501][500] = .GRASS;
}

game_ui :: () {
	
}

game_tick :: () {

}

game_draw :: () {
	camtask := Rendering_Task_Set_Camera.{type = .SET_CAMERA, camera = cam};
	add_rendering_task(camtask);
	skytask := Rendering_Task_Sky.{type = .SKY, worldConfig = *world.conf};
	add_rendering_task(skytask);
	groundtask := Rendering_Task_Ground.{type = .GROUND, world = *world};
	add_rendering_task(groundtask);
}
