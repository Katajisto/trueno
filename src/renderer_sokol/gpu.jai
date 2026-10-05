// Float, so brightness above 1 survives until post-processing.
VIEW_COLOR_FORMAT :: sg_pixel_format.RGBA16F;
VIEW_DEPTH_FORMAT :: sg_pixel_format.DEPTH;
VIEW_SCENE_FORMAT :: sg_pixel_format.R32F;
VIEW_GLOW_FORMAT  :: sg_pixel_format.R16F;
SHADOW_TINT_FORMAT :: sg_pixel_format.RGBA16F;   // glass colour, and the nearest glass depth in alpha

ALPHA_BLEND :: sg_blend_state.{
    enabled        = true,
    src_factor_rgb = .SRC_ALPHA,
    dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
};

MULTIPLY_BLEND :: sg_blend_state.{
    enabled        = true,
    src_factor_rgb = .DST_COLOR,
    dst_factor_rgb = .ZERO,
};

ADDITIVE_BLEND :: sg_blend_state.{
    enabled        = true,
    src_factor_rgb = .SRC_ALPHA,
    dst_factor_rgb = .ONE,
};

Pipeline_Target :: enum {
    SCREEN;
    VIEW_OPAQUE;
    VIEW_TRANSPARENT;
    SHADOW;
    POST;     // colour only, view format
}

samplers : struct {
    nearest_clamp : sg_sampler;
    linear_clamp  : sg_sampler;
    linear_repeat : sg_sampler;
    shadow        : sg_sampler;
}

samplers_init :: () {
    samplers.nearest_clamp = sg_make_sampler(*(sg_sampler_desc.{ min_filter = .NEAREST, mag_filter = .NEAREST, wrap_u = .CLAMP_TO_EDGE, wrap_v = .CLAMP_TO_EDGE }));
    samplers.linear_clamp  = sg_make_sampler(*(sg_sampler_desc.{ min_filter = .LINEAR,  mag_filter = .LINEAR,  wrap_u = .CLAMP_TO_EDGE, wrap_v = .CLAMP_TO_EDGE }));
    samplers.linear_repeat = sg_make_sampler(*(sg_sampler_desc.{ min_filter = .LINEAR,  mag_filter = .LINEAR,  wrap_u = .REPEAT,        wrap_v = .REPEAT }));
    samplers.shadow        = sg_make_sampler(*(sg_sampler_desc.{ min_filter = .NEAREST, mag_filter = .NEAREST, wrap_u = .CLAMP_TO_EDGE, wrap_v = .CLAMP_TO_EDGE, compare = .LESS_EQUAL }));
}

// Vertex layout and anything else specific is filled in by the caller.
pipeline_desc :: (shader: sg_shader_desc, target: Pipeline_Target, blend := sg_blend_state.{}, depth_write := false) -> sg_pipeline_desc {
    shader_desc := shader;
    desc : sg_pipeline_desc;
    desc.shader = sg_make_shader(*shader_desc);
    desc.colors[0].blend = blend;
    if target != .SCREEN {
        desc.colors[0].pixel_format = VIEW_COLOR_FORMAT;
        desc.depth.pixel_format     = VIEW_DEPTH_FORMAT;
        desc.depth.compare          = .LESS_EQUAL;
        desc.depth.write_enabled    = depth_write;
        desc.sample_count           = 1;
    }
    // Glow is attachment 1 in both view passes, blended like colour.
    if target == .VIEW_OPAQUE || target == .VIEW_TRANSPARENT {
        desc.color_count            = 2;
        desc.colors[1].pixel_format = VIEW_GLOW_FORMAT;
        desc.colors[1].blend        = blend;
    }
    if target == .VIEW_OPAQUE {
        desc.color_count            = 3;
        desc.colors[2].pixel_format = VIEW_SCENE_FORMAT;
    }
    // Shadow casters write depth only; glass turns the tint back on.
    if target == .SHADOW {
        desc.colors[0].pixel_format = SHADOW_TINT_FORMAT;
        desc.colors[0].write_mask   = .NONE;
    }
    if target == .POST    desc.depth.pixel_format = .NONE;
    return desc;
}

Pass_Kind :: enum {
    MAIN;
    REFLECTION;
    SHADOW;
}

Pass :: struct {
    scene      : *Scene;
    view_index : int;
    view       : View;
    kind       : Pass_Kind;
    params     : View_Params;
    shadow     : Shadow_Params;
}

make_pass :: (scene: *Scene, view_index: int, kind: Pass_Kind) -> Pass {
    pass := Pass.{ scene = scene, view_index = view_index, view = scene.views[view_index], kind = kind };
    env := view_environment(pass.view);
    height := env.reflection_height;

    camera := pass.view.camera.position;
    view_proj := scene.view_proj[view_index];
    pass.params.clip = .[0, 0, 0, 1];
    if kind == .REFLECTION {
        camera.y  = 2 * height - camera.y;
        view_proj = scene.reflection_view_proj[view_index];
        pass.params.clip = .[0, 1, 0, -height];
    }
    if kind == .SHADOW {
        // Camera-facing billboards turn to the sun, so they cast their full silhouette.
        camera    = pass.view.camera.target + env.sun_direction * 1000;
        view_proj = scene.shadow_view_proj[view_index];
    }
    _, inv_view_proj := inverse(view_proj);
    pass.params.view_proj     = view_proj.floats;
    pass.params.inv_view_proj = inv_view_proj.floats;
    pass.params.camera    = .[camera.x, camera.y, camera.z, scene.time];
    pass.params.sun_direction = .[env.sun_direction.x, env.sun_direction.y, env.sun_direction.z, 0];
    pass.params.sun_color     = .[env.sun_color.x, env.sun_color.y, env.sun_color.z, 0];
    pass.params.shade_color   = .[env.shade_color.x, env.shade_color.y, env.shade_color.z, 0];

    // From shadow clip space to shadow map uv and stored depth, which differ per backend.
    gl := sg_query_backend() == .GLCORE || sg_query_backend() == .GLES3;
    flip := sg_query_features().origin_top_left;
    to_uv := Matrix4.{
        0.5, 0, 0, 0.5,
        0, ifx flip then -0.5 else 0.5, 0, 0.5,
        0, 0, ifx gl then 0.5 else 1, ifx gl then 0.5 else 0,
        0, 0, 0, 1,
    };
    pass.shadow.shadow_uv = (scene.shadow_view_proj[view_index] * transpose(to_uv)).floats;
    return pass;
}

apply_uniforms :: (slot: s32, params: *$T) {
    sg_apply_uniforms(slot, *(sg_range.{ params, size_of(T) }));
}

Slots :: struct (T: Type) {
    items : [..]T;
    free  : [..]u32;
}

// Ids start at 1 so that 0 can mean none.
slot_add :: (slots: *Slots($T)) -> u32, *T {
    if slots.free.count {
        id := pop(*slots.free);
        return id, *slots.items[id - 1];
    }
    item := array_add(*slots.items);
    return xx slots.items.count, item;
}

slot_get :: (slots: *Slots($T), id: u32) -> *T {
    if id == 0 || id > slots.items.count  return null;
    return *slots.items[id - 1];
}

slot_remove :: (slots: *Slots($T), id: u32) {
    slots.items[id - 1] = .{};
    array_add(*slots.free, id);
}

Stream_Buffer :: struct {
    buffer : sg_buffer;
    size   : int;
}

stream_upload :: (stream: *Stream_Buffer, data: []$T) {
    if data.count == 0  return;
    size := data.count * size_of(T);
    if size > stream.size {
        if stream.size  sg_destroy_buffer(stream.buffer);
        stream.size   = max(size, stream.size * 2);
        stream.buffer = sg_make_buffer(*(sg_buffer_desc.{ size = xx stream.size, usage = .STREAM }));
    }
    sg_update_buffer(stream.buffer, *(sg_range.{ data.data, xx size }));
}

Keyed :: struct (Instance: Type) {
    key      : s64;
    instance : Instance;
}

Batch :: struct {
    view_index : s32;
    key        : s64;
    first      : s32;
    count      : s32;
}

// Sorts the view's draws by key and appends one batch per run of equal keys.
batch_instances :: (view_index: int, draws: []Keyed($I), batches: *[..]Batch, instances: *[..]I) {
    quick_sort(draws, (a: Keyed(I), b: Keyed(I)) -> s64 { return a.key - b.key; });
    for draws {
        if it_index == 0 || draws[it_index - 1].key != it.key {
            array_add(batches, .{view_index = xx view_index, key = it.key, first = xx instances.count});
        }
        array_add(instances, it.instance);
        batches.*[batches.count - 1].count += 1;
    }
}

bind_shadow :: (pass: *Pass, bind: *sg_bindings) {
    bind.images[IMG_shadow_map] = view_shadow_image(pass.view_index);
    bind.samplers[SMP_shadow_smp] = samplers.shadow;
    bind.images[IMG_shadow_tint] = view_shadow_tint_image(pass.view_index);
    bind.samplers[SMP_shadow_tint_smp] = samplers.nearest_clamp;
}

view_environment :: (view: View) -> Environment {
    return ifx view.environment then view.environment.* else .{};
}
