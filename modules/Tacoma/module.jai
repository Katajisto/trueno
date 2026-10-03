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
    sunIntensity     : float = 1.0;
    skyIntensity     : float = 10.0;
    skyDesaturation  : float = 0.0;
}

// emission is the light it gives off, already scaled. Glass is seen as a solid
// surface but lets the sun through, tinted by its colour.
Swatch :: struct {
  color    : Vector3;
  emission : Vector3;
  glass    : s32;
}

SWATCH_COUNT :: 256;
PROBE_FLOATS :: 13;   // R, G, B × (c0, y, z, x), then the fraction of rays that hit a back face

Trile_Data :: struct {
  trixels     : [16][16][16]u8;   // swatch ids, 0 = empty
  vertices    : *float;
  vertexCount : s32;
}

Trile_Set :: struct {
  triles : *Trile_Data;
  count  : s32;
}

World_Trile :: struct {
  index       : s32;
  position    : Vector3;
  orientation : s32;
}

World :: struct {
  triles : *World_Trile;
  count  : s32;
}

Tacoma_Context :: struct {}

tacoma_init       :: (base_path: *u8) -> *Tacoma_Context #foreign libtacoma;
tacoma_destroy    :: (ctx: *Tacoma_Context) #foreign libtacoma;
tacoma_load_scene :: (ctx: *Tacoma_Context, sky: Sky_Config, swatches: *Swatch, ts: Trile_Set, world: World, include_water: s32) #foreign libtacoma;
tacoma_render_rdm       :: (ctx: *Tacoma_Context, world_trile_index: s32, roughness: s32, quality: s32, size: s32) -> *float #foreign libtacoma;
tacoma_render_reference :: (ctx: *Tacoma_Context, width: s32, height: s32, eye: Vector3, target: Vector3, roughness: float, quality: s32) -> *float  #foreign libtacoma;
tacoma_render_sh_chunk  :: (ctx: *Tacoma_Context, origin_x: float, origin_y: float, origin_z: float, probe_n: s32, probe_spacing: float, quality: s32) -> *float #foreign libtacoma;

tacoma_free_result :: (data: *float) #foreign libtacoma;

libtacoma :: #library "libtacoma";
