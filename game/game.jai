#scope_file

char_pos : Vector3 = .{0.0, 1.5, 0.0};
rotation : float   = 0.0;

cam : Camera = .{
	far = 2000.0,
	near = 1.0,
	target = .{0.0, 0.0, 0.0},
	position = .{0.0, 0.0, 0.0}
};

#scope_export
game_init :: () {
}

game_tick :: () {
	speed := 0.1;

	forward := Vector3.{1.0, 0.0, 0.0};

	char_pos += speed * forward;
		
	cam.position = char_pos;
	cam.target   = char_pos + forward;
}

game_draw :: () {
	if is_in_reflection_pass {
		cam.position.y *= -1;
		cam.target.y *= -1;
	}
	draw_sky(*cam);
	if !is_in_reflection_pass then draw_ground_plane(*cam);
	if is_in_reflection_pass {
		cam.position.y *= -1;
		cam.target.y *= -1;
	}
}
