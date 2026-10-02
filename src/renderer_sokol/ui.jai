ui_init :: () {
    desc := pipeline_desc(ui_shader_desc(sg_query_backend()), .SCREEN, blend = true);
    desc.layout.attrs[ATTR_ui_position] = .{ format = .FLOAT2 };
    desc.layout.attrs[ATTR_ui_uv]       = .{ format = .FLOAT2 };
    desc.layout.attrs[ATTR_ui_color0]   = .{ format = .FLOAT4 };
    ui.pipeline = sg_make_pipeline(*desc);
}

ui_upload :: (scene: *Scene) {
    array_reset_keeping_memory(*ui.vertices);
    for scene.ui  array_add(*ui.vertices, ..it.vertices);
    stream_upload(*ui.stream, ui.vertices);
}

ui_draw :: (scene: *Scene, w: s32, h: s32) {
    if ui.vertices.count == 0  return;

    sg_apply_pipeline(ui.pipeline);
    params := Ui_Vs_Params.{ screen_size = .[xx w, xx h] };
    apply_uniforms(UB_ui_vs_params, *params);

    bind : sg_bindings;
    bind.vertex_buffers[0] = ui.stream.buffer;
    bind.samplers[SMP_smp] = samplers.nearest_clamp;

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
    stream      : Stream_Buffer;
    vertices    : [..]Ui_Vertex;
}
