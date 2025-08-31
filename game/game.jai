#scope_file

cam : Camera = .{
	far = 2000.0,
	near = 1.0
};

#scope_export
game_init :: () {
}

game_tick :: () {
}

game_draw :: () {
	draw_sky(*cam);
}
