#scope_file

char_pos : Vector3 = .{0.0, 1.5, 0.0};
rotation : float   = 0.0;

cam : Camera = .{
	far = 2000.0,
	near = 1.0,
	target = .{0.0, 0.0, 0.0},
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

game_tick :: () {
}

game_draw :: () {
	if !is_in_reflection_pass then update_image_from_ground(*world, *gPipelines.plane.bind.images[1]);
	if is_in_reflection_pass {
		cam.position.y *= -1;
		cam.target.y *= -1;
	}
	draw_sky(*cam);
	if !is_in_reflection_pass then draw_ground_plane(*cam, *world.conf);
	if is_in_reflection_pass {
		cam.position.y *= -1;
		cam.target.y *= -1;
	}
}
