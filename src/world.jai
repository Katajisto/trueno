World_Config :: struct {
    // All of the @Notes are for the autoedit functionality.
    skyBase       : Vector3 = .{0.38, 0.81, 0.95}; @Color
    skyTop        : Vector3 = .{0.17, 0.4, 0.95}; @Color
    sunDisk       : Vector3 = .{1.0, 1.0, 1.0}; @Color
    horizonHalo   : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunHalo       : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunLightColor : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunPosition   : Vector3 = #run normalize(Vector3.{0.2, 0.3, 0.4});
    sunIntensity  : float = 2.0; @Slider,0,10,0.5

    hasClouds     : s32 = 1; @Slider,0,1,1

    hasPlane      : s32  = 0; @Slider,0,1,1
    planeHeight   : float = 0.0; @Slider,-100,100,1
    planeType     : s32   = 0; @Slider,0,2,1
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
    #insert #run,stallable generate_copy_code();
}

IVector3 :: struct {
    x: s32;
    y: s32;
    z: s32;
}

ivec_comp :: (a: IVector3, b: IVector3) -> bool {
    if a.x != b.x || a.y != b.y || a.z != b.z then return false;
    return true;
}

ivec_hash :: (v: IVector3) -> u32 {
    return sdbm_hash(*v, size_of(IVector3));
}


World :: struct {
    conf   : World_Config;
    triles : Table(IVector3, string, ivec_hash, ivec_comp);
}
