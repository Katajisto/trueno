#scope_file

char_pos : Vector3 = .{0.0, 0.0, 0.0};
rotation : float   = 0.0;

cam : Camera = .{
	far = 2000.0,
	near = 1.0,
	target = .{0.0, 0.0, 0.0},
	position = .{5.0, 5.0, 0.0}
};

#scope_export
game_engine_config :: () {
}

game_init :: () {
}

game_ui :: () {
	
}

game_tick :: () {
	speed := 0.1;
	if input_button_states[#char "W"] & .DOWN then char_pos += speed * Vector3.{-1.0, 0.0, 0.0};
	if input_button_states[#char "S"] & .DOWN then char_pos += speed * Vector3.{1.0, 0.0, 0.0};
	if input_button_states[#char "A"] & .DOWN then char_pos += speed * Vector3.{0.0, 0.0, 1.0};
	if input_button_states[#char "D"] & .DOWN then char_pos += speed * Vector3.{0.0, 0.0, -1.0};
	cam.target = char_pos;
	cam.position = char_pos + .{10,5,0};
}

game_draw :: () {
	curworld := get_current_world();
	if curworld.valid {
		create_set_cam_rendering_task(cam, curworld.world.conf.planeHeight);
		create_world_rendering_tasks(curworld.world);
	}
}
