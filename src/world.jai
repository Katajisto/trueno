World_Config :: struct {
    skyBase       : Vector3 = .{0.38, 0.81, 0.95};
    skyTop        : Vector3 = .{0.17, 0.4, 0.95};
    sunDisk       : Vector3 = .{1.0, 1.0, 1.0};
    horizonHalo   : Vector3 = .{1.0, 1.0, 1.0};
    sunHalo       : Vector3 = .{1.0, 1.0, 1.0};
    sunLightColor : Vector3 = .{1.0, 1.0, 1.0};
    sunPosition   : Vector3 = #run normalize(Vector3.{0.5, 0.5, 0.5});
    sunIntensity  : float = 2.0;

    hasClouds     : int = 1;

    hasPlane      : int  = 0;
    planeHeight   : float = 0.0;
    planeType     : int   = 0;
}

world_config_to_shader_type :: (wc: *World_Config, data: *$T) {
    data.skyBase = wc.skyBase.component;
    data.skyTop = wc.skyTop.component;
    data.sunDisk = wc.sunDisk.component;
    data.horizonHalo = wc.horizonHalo.component;
    data.sunHalo = wc.sunHalo.component;
    data.time = cast(float) get_time();
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
