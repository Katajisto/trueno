lines_init :: () {
    make :: (depth_test: bool) -> sg_pipeline {
        desc := pipeline_desc(line_shader_desc(sg_query_backend()), .VIEW_TRANSPARENT, ALPHA_BLEND);
        desc.layout.buffers[0].step_func = .PER_INSTANCE;
        desc.layout.attrs[ATTR_line_a]     = .{ format = .FLOAT3 };
        desc.layout.attrs[ATTR_line_b]     = .{ format = .FLOAT3 };
        desc.layout.attrs[ATTR_line_color] = .{ format = .FLOAT4 };
        desc.layout.attrs[ATTR_line_width] = .{ format = .FLOAT };
        if !depth_test  desc.depth.compare = .ALWAYS;
        return sg_make_pipeline(*desc);
    }
    lines.depth_tested = make(true);
    lines.overlay      = make(false);
}

lines_upload :: (scene: *Scene) {
    array_reset_keeping_memory(*lines.all);
    array_add(*lines.all, ..scene.debug_lines);
    array_add(*lines.all, ..scene.overlay_lines);
    stream_upload(*lines.stream, lines.all);
}

lines_draw :: (pass: *Pass, width: s32, height: s32) {
    if pass.kind != .MAIN  return;
    params := Line_Params.{ viewport = .[width * 0.5, height * 0.5] };

    draw :: (pipeline: sg_pipeline, first: int, count: int) #expand {
        if count == 0  return;
        sg_apply_pipeline(pipeline);
        apply_uniforms(UB_view_params, *pass.params);
        apply_uniforms(UB_line_params, *params);
        bind : sg_bindings;
        bind.vertex_buffers[0]        = lines.stream.buffer;
        bind.vertex_buffer_offsets[0] = xx (first * size_of(Debug_Line));
        sg_apply_bindings(*bind);
        sg_draw(0, 6, xx count);
    }
    draw(lines.depth_tested, 0, pass.scene.debug_lines.count);
    draw(lines.overlay, pass.scene.debug_lines.count, pass.scene.overlay_lines.count);
}

#scope_file

lines : struct {
    depth_tested : sg_pipeline;
    overlay      : sg_pipeline;
    all          : [..]Debug_Line;
    stream       : Stream_Buffer;
}
