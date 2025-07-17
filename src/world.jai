World_Config :: struct {
    skyBase       : Vector3 = .{0.5, 0.5, 1.0};
    skyTop        : Vector3 = .{0.8, 0.8, 1.0};
    sunDisk       : Vector3;
    horizonHalo   : Vector3;
    sunHalo       : Vector3;
    sunLightColor : Vector3 = .{1.0, 1.0, 1.0};
    sunPosition   : Vector3 = #run normalize(Vector3.{0.5, 0.5, 0.5});
    sunIntensity  : float = 1.0;

    hasClouds     : int = 1;

    hasPlane      : int  = 0;
    planeHeight   : float = 0.0;
    planeType     : int   = 0;
}

world_config_to_shader_type :: (wc: World_Config, data: *$T) {
    data.skyBase[0] = wc.skyBase.x;
    data.skyBase[1] = wc.skyBase.y;
    data.skyBase[2] = wc.skyBase.z;
    data.skyTop[0] = wc.skyTop.x;
    data.skyTop[1] = wc.skyTop.y;
    data.skyTop[2] = wc.skyTop.z;
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
