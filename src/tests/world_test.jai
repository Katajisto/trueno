test_floor_div_mod :: () {
    s := begin_suite("floor_div / floor_mod");

    check(*s, "floor_div( 0,  32) ==  0",  floor_div( 0,  32) ==  0);
    check(*s, "floor_div( 1,  32) ==  0",  floor_div( 1,  32) ==  0);
    check(*s, "floor_div(31,  32) ==  0",  floor_div(31,  32) ==  0);
    check(*s, "floor_div(32,  32) ==  1",  floor_div(32,  32) ==  1);
    check(*s, "floor_div(33,  32) ==  1",  floor_div(33,  32) ==  1);
    check(*s, "floor_div(-1,  32) == -1",  floor_div(-1,  32) == -1);
    check(*s, "floor_div(-32, 32) == -1",  floor_div(-32, 32) == -1);
    check(*s, "floor_div(-33, 32) == -2",  floor_div(-33, 32) == -2);

    check(*s, "floor_mod( 0,  32) ==  0",  floor_mod( 0,  32) ==  0);
    check(*s, "floor_mod( 1,  32) ==  1",  floor_mod( 1,  32) ==  1);
    check(*s, "floor_mod(31,  32) == 31",  floor_mod(31,  32) == 31);
    check(*s, "floor_mod(32,  32) ==  0",  floor_mod(32,  32) ==  0);
    check(*s, "floor_mod(33,  32) ==  1",  floor_mod(33,  32) ==  1);
    check(*s, "floor_mod(-1,  32) == 31",  floor_mod(-1,  32) == 31);
    check(*s, "floor_mod(-32, 32) ==  0",  floor_mod(-32, 32) ==  0);
    check(*s, "floor_mod(-33, 32) == 31",  floor_mod(-33, 32) == 31);

    end_suite(s);
}

test_coord_roundtrip :: () {
    s := begin_suite("world coord round-trip");

    roundtrip_check :: (suite: *Test_Suite, wx: s32, wy: s32, wz: s32) {
        ck := world_to_chunk_coord(wx, wy, wz);
        lx, ly, lz := world_to_local(wx, wy, wz);
        rx, ry, rz := chunk_local_to_world(ck, lx, ly, lz);
        check(suite, tprint("(%, %, %) round-trips", wx, wy, wz), rx == wx && ry == wy && rz == wz);
    }

    roundtrip_check(*s,   0,   0,   0);
    roundtrip_check(*s,   1,   1,   1);
    roundtrip_check(*s,  31,  31,  31);
    roundtrip_check(*s,  32,  32,  32);
    roundtrip_check(*s,  33,  33,  33);
    roundtrip_check(*s,  -1,  -1,  -1);
    roundtrip_check(*s, -32, -32, -32);
    roundtrip_check(*s, -33, -33, -33);
    roundtrip_check(*s,  63,  -1,  32);

    end_suite(s);
}

test_chunk_coord_values :: () {
    s := begin_suite("world_to_chunk_coord values");

    check(*s, "( 0, 0, 0) -> chunk ( 0, 0, 0)", world_to_chunk_coord( 0,  0,  0) == .{ 0,  0,  0});
    check(*s, "(31, 0, 0) -> chunk ( 0, 0, 0)", world_to_chunk_coord(31,  0,  0) == .{ 0,  0,  0});
    check(*s, "(32, 0, 0) -> chunk ( 1, 0, 0)", world_to_chunk_coord(32,  0,  0) == .{ 1,  0,  0});
    check(*s, "(-1, 0, 0) -> chunk (-1, 0, 0)", world_to_chunk_coord(-1,  0,  0) == .{-1,  0,  0});
    check(*s, "(-32,0, 0) -> chunk (-1, 0, 0)", world_to_chunk_coord(-32, 0,  0) == .{-1,  0,  0});
    check(*s, "(-33,0, 0) -> chunk (-2, 0, 0)", world_to_chunk_coord(-33, 0,  0) == .{-2,  0,  0});

    end_suite(s);
}

#run {
    test_floor_div_mod();
    test_coord_roundtrip();
    test_chunk_coord_values();
}
