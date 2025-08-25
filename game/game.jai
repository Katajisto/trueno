#scope_file

cam : Camera = .{
	far = 1000.0
};

#scope_export
game_init :: () {
}

game_tick :: () {
}

game_draw :: () {
	draw_sky(*cam);
}
