billboards_init :: () {
    desc := pipeline_desc(billboard_shader_desc(sg_query_backend()), .VIEW, depth_write = true);
    desc.layout.buffers[0].step_func = .PER_INSTANCE;
    desc.layout.attrs[ATTR_billboard_center]  = .{ format = .FLOAT3 };
    desc.layout.attrs[ATTR_billboard_size]    = .{ format = .FLOAT2 };
    desc.layout.attrs[ATTR_billboard_uv_rect] = .{ format = .FLOAT4 };
    desc.layout.attrs[ATTR_billboard_face]    = .{ format = .FLOAT3 };
    billboards.pipeline = sg_make_pipeline(*desc);
}

billboards_upload :: (scene: *Scene) {
    array_reset_keeping_memory(*billboards.instances);
    array_reset_keeping_memory(*billboards.batches);

    draws : [..]Keyed(Instance);
    draws.allocator = temp;
    for view_index: 0..scene.views.count-1 {
        array_reset_keeping_memory(*draws);
        for scene.billboards {
            if it.view.index != view_index  continue;
            array_add(*draws, .{it.sheet.id, .{it.position, it.size, it.uv_rect, it.face}});
        }
        batch_instances(view_index, draws, *billboards.batches, *billboards.instances);
    }
    stream_upload(*billboards.stream, billboards.instances);
}

billboards_draw :: (pass: *Pass) {
    sg_apply_pipeline(billboards.pipeline);
    apply_uniforms(UB_view_params, *pass.params);

    for billboards.batches {
        if it.view_index != pass.view_index  continue;

        bind : sg_bindings;
        bind.vertex_buffers[0]        = billboards.stream.buffer;
        bind.vertex_buffer_offsets[0] = it.first * size_of(Instance);
        bind.images[IMG_sprite]       = texture_image(xx it.key);
        bind.samplers[SMP_sprite_smp] = samplers.nearest_clamp;
        sg_apply_bindings(*bind);
        sg_draw(0, 6, it.count);
    }
}

#scope_file

Instance :: struct {
    center  : Vector3;
    size    : Vector2;
    uv_rect : Vector4;
    face    : Vector3;
}

billboards : struct {
    pipeline  : sg_pipeline;
    instances : [..]Instance;
    batches   : [..]Batch;
    stream    : Stream_Buffer;
}
