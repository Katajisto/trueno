ui_init :: () {
    shader_desc := ui_shader_desc(sg_query_backend());

    desc : sg_pipeline_desc;
    desc.shader = sg_make_shader(*shader_desc);
    desc.layout.attrs[ATTR_ui_position] = .{ format = .FLOAT2 };
    desc.layout.attrs[ATTR_ui_uv]       = .{ format = .FLOAT2 };
    desc.layout.attrs[ATTR_ui_color0]   = .{ format = .FLOAT4 };
    desc.colors[0].blend = .{
        enabled        = true,
        src_factor_rgb = .SRC_ALPHA,
        dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
    };
    ui.pipeline = sg_make_pipeline(*desc);

    ui.sampler = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u     = .CLAMP_TO_EDGE,
        wrap_v     = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));
}

ui_upload :: (scene: *Scene) {
    array_reset_keeping_memory(*ui.vertices);
    for scene.ui  array_add(*ui.vertices, ..it.vertices);
    if ui.vertices.count == 0  return;

    size := ui.vertices.count * size_of(Ui_Vertex);
    if size > ui.buffer_size {
        if ui.buffer_size  sg_destroy_buffer(ui.buffer);
        ui.buffer_size = max(size, ui.buffer_size * 2);
        ui.buffer = sg_make_buffer(*(sg_buffer_desc.{ size = xx ui.buffer_size, usage = .STREAM }));
    }
    sg_update_buffer(ui.buffer, *(sg_range.{ ui.vertices.data, xx size }));
}

ui_draw :: (scene: *Scene, w: s32, h: s32) {
    if ui.vertices.count == 0  return;

    sg_apply_pipeline(ui.pipeline);
    params := Ui_Vs_Params.{ screen_size = .[xx w, xx h] };
    sg_apply_uniforms(UB_ui_vs_params, *(sg_range.{ *params, size_of(Ui_Vs_Params) }));

    bind : sg_bindings;
    bind.vertex_buffers[0] = ui.buffer;
    bind.samplers[SMP_smp] = ui.sampler;

    first : s32;
    for scene.ui {
        if it.set_scissor {
            s := it.scissor;
            sg_apply_scissor_rect(s.x, s.y, max(s.w, 0), max(s.h, 0), true);
        } else if it.clear_scissor {
            sg_apply_scissor_rect(0, 0, w, h, true);
        } else if it.vertices.count {
            bind.images[IMG_tex] = texture_image(it.texture.id);
            sg_apply_bindings(*bind);
            sg_draw(first, xx it.vertices.count, 1);
            first += xx it.vertices.count;
        }
    }
}

#scope_file

ui : struct {
    pipeline    : sg_pipeline;
    sampler     : sg_sampler;
    buffer      : sg_buffer;
    buffer_size : int;
    vertices    : [..]Ui_Vertex;
}
