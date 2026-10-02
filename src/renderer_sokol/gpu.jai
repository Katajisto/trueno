VIEW_COLOR_FORMAT :: sg_pixel_format.RGBA8;
VIEW_DEPTH_FORMAT :: sg_pixel_format.DEPTH;

ALPHA_BLEND :: sg_blend_state.{
    enabled        = true,
    src_factor_rgb = .SRC_ALPHA,
    dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
};

Pipeline_Target :: enum {
    SCREEN;
    VIEW;
}

samplers : struct {
    nearest_clamp : sg_sampler;
    linear_clamp  : sg_sampler;
    linear_repeat : sg_sampler;
}

samplers_init :: () {
    samplers.nearest_clamp = sg_make_sampler(*(sg_sampler_desc.{ min_filter = .NEAREST, mag_filter = .NEAREST, wrap_u = .CLAMP_TO_EDGE, wrap_v = .CLAMP_TO_EDGE }));
    samplers.linear_clamp  = sg_make_sampler(*(sg_sampler_desc.{ min_filter = .LINEAR,  mag_filter = .LINEAR,  wrap_u = .CLAMP_TO_EDGE, wrap_v = .CLAMP_TO_EDGE }));
    samplers.linear_repeat = sg_make_sampler(*(sg_sampler_desc.{ min_filter = .LINEAR,  mag_filter = .LINEAR,  wrap_u = .REPEAT,        wrap_v = .REPEAT }));
}

// Vertex layout and anything else specific is filled in by the caller.
pipeline_desc :: (shader: sg_shader_desc, target: Pipeline_Target, blend := false, depth_write := false) -> sg_pipeline_desc {
    shader_desc := shader;
    desc : sg_pipeline_desc;
    desc.shader = sg_make_shader(*shader_desc);
    if blend  desc.colors[0].blend = ALPHA_BLEND;
    if target == .VIEW {
        desc.colors[0].pixel_format = VIEW_COLOR_FORMAT;
        desc.depth.pixel_format     = VIEW_DEPTH_FORMAT;
        desc.depth.compare          = .LESS_EQUAL;
        desc.depth.write_enabled    = depth_write;
        desc.sample_count           = 1;
    }
    return desc;
}

Pass :: struct {
    scene      : *Scene;
    view_index : int;
    view       : View;
    reflection : bool;
    params     : View_Params;
}

make_pass :: (scene: *Scene, view_index: int, reflection: bool) -> Pass {
    pass := Pass.{ scene = scene, view_index = view_index, view = scene.views[view_index], reflection = reflection };
    height := ifx pass.view.environment then pass.view.environment.reflection_height else 0;

    camera := pass.view.camera.position;
    view_proj := scene.view_proj[view_index];
    pass.params.clip = .[0, 0, 0, 1];
    if reflection {
        camera.y  = 2 * height - camera.y;
        view_proj = scene.reflection_view_proj[view_index];
        pass.params.clip = .[0, 1, 0, -height];
    }
    pass.params.view_proj = view_proj.floats;
    pass.params.camera    = .[camera.x, camera.y, camera.z, scene.time];
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
