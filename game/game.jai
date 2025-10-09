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
	create_set_cam_rendering_task(cam);
	create_world_rendering_tasks(*world);
}
