#scope_file
cam   : Camera;
world : World;
#scope_export

game_init :: () {
    print("Game init...\n");
    cam.position = .{5,5,5};
    cam.target   = .{3,6,3};
    cam.near     = 0.1;
    cam.far      = 5000;
}

game_tick :: () {
}

game_draw :: () {
    draw_sky(*cam, *world.conf);
}
