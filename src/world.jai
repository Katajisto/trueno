World_Config :: struct {
    // All of the @Notes are for the autoedit functionality.
    skyBase       : Vector3 = .{0.38, 0.81, 0.95}; @Color
    skyTop        : Vector3 = .{0.17, 0.4, 0.95}; @Color
    sunDisk       : Vector3 = .{1.0, 1.0, 1.0}; @Color
    horizonHalo   : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunHalo       : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunLightColor : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunPosition   : Vector3 = #run normalize(Vector3.{0.2, 0.3, 0.4});
    sunIntensity  : float = 2.0; @Slider,0,100,0.5
    skyIntensity  : float = 2.0; @Slider,0,10,0.5

    hasClouds     : s32 = 1; @Slider,0,1,1

    hasPlane      : s32  = 0; @Slider,0,1,1
    planeHeight   : float = 0.0; @Slider,-100,100,1
    planeType     : s32   = 1; @Slider,0,1,1

    grassDensity  : float = 40000; @Slider,10000,100000,1000
}

// Copies over all the fields of our world config into a given shader type.
// Requires that the shader type has all of the fields the world config has.
world_config_to_shader_type :: (wc: *World_Config, data: *$T) {
    generate_copy_code :: () -> string {
        builder : String_Builder;
        ti := type_info(World_Config);
        for ti.members {
            if it.type == type_info(Vector3) then print_to_builder(*builder, "data.% = wc.%.component;\n", it.name, it.name);
            else print_to_builder(*builder, "data.% = wc.%;\n", it.name, it.name);
        }
        return builder_to_string(*builder);
    }
    data.time = xx get_time();
    #insert #run,stallable generate_copy_code();
}

TrilePositions :: struct {
    trileName: string;
    positions: [..]Vector4;
}

World :: struct {
    // @ToDo: Add a pool into here so we allocate all of the world stuff in it's own pool.
    conf      : World_Config;
    positions : [..]TrilePositions;
}
