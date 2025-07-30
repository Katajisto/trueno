#import "Math";

#scope_export

Sky_Config :: struct {
  skyBase       : Vector3 = .{0.5, 0.5, 1.0};
  skyTop        : Vector3 = .{0.8, 0.8, 1.0};
  sunDisk       : Vector3;
  horizonHalo   : Vector3;
  sunHalo       : Vector3;
  sunLightColor : Vector3 = .{1.0, 1.0, 1.0};
  sunPosition   : Vector3 = #run normalize(Vector3.{0.5, 0.5, 0.5});
  sunIntensity  : float = 1.0;
  skyIntensity  : float = 10.0;
}

Trixel_Data :: struct {
    empty    : bool    = false;
    color    : Vector3 = .{1.0, 0.0, 0.0};
    material : float   = 1.0;
}

Trile_Data :: struct {
    trixels     : [16][16][16]Trixel_Data;
    vertices    : *float;
    vertexCount : s32;
}

Trile_Set :: struct {
    triles : *Trile_Data;
    count  : s32;
}

World_Trile :: struct {
    index    : s32;
    position : Vector3;
}

World :: struct {
    triles : *World_Trile;
    count  : s32;
}

Gen_Config :: struct {
    target       : Vector3 = .{0.0, 0.0, 0.0};
    eye          : Vector3 = .{5.0, 5.0, 5.0};
    samples      : s32     = 100;
    render_water : bool    = false;
}

do_gen :: (path: *u8, rwidth: s32, rheight: s32, sky: Sky_Config, ts: Trile_Set, world: World, config: Gen_Config) -> *float #foreign libtacoma "do_gen";

libtacoma :: #library "libtacoma";
