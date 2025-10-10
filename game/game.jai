#scope_file

char_pos : Vector3 = .{0.0, 1.5, 0.0};
rotation : float   = 0.0;

cam : Camera = .{
	far = 2000.0,
	near = 1.0,
	target = .{0.0, 4.0, 0.0},
	position = .{3.0, 5.0, 3.0}
};

#scope_export
game_init :: () {
}

game_ui :: () {
	
}

game_tick :: () {

}

game_draw :: () {
	create_set_cam_rendering_task(cam);
	curworld := get_current_world();
	if curworld.valid then create_world_rendering_tasks(curworld.world);
}
