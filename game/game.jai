#scope_file

cam : Camera = .{
	far = 2000.0,
	near = 1.0,
	target = .{0.0, 0.0, 0.0},
	position = .{10.0, 10.0, 10.0}
};

#scope_export
game_init :: () {
}

game_tick :: () {
	cam.position += Vector3.{0.01, 0.0, 0.0};
	cam.target += Vector3.{0.01, 0.0, 0.0};
}

game_draw :: () {
	draw_sky(*cam);
	draw_ground_plane(*cam);
}
