triles_init :: (orientations: [ORIENTATION_COUNT]Matrix3) {
    desc := pipeline_desc(trile_shader_desc(sg_query_backend()), .VIEW_OPAQUE, depth_write = true);
    desc.layout.buffers[1].step_func = .PER_INSTANCE;
    desc.layout.attrs[ATTR_trile_position] = .{ format = .FLOAT3 };
    desc.layout.attrs[ATTR_trile_data_n]     = .{ format = .UBYTE4N };
    desc.layout.attrs[ATTR_trile_instance] = .{ format = .FLOAT4, buffer_index = 1 };
    desc.layout.attrs[ATTR_trile_tint]     = .{ format = .FLOAT,  buffer_index = 1 };
    desc.layout.attrs[ATTR_trile_cut]      = .{ format = .FLOAT,  buffer_index = 1 };
    desc.index_type   = .UINT16;
    desc.cull_mode    = .BACK;
    desc.face_winding = .CCW;
    triles.pipeline = sg_make_pipeline(*desc);

    // Back faces only, so lit faces don't shadow themselves.
    shadow_desc := pipeline_desc(trile_shadow_shader_desc(sg_query_backend()), .SHADOW, depth_write = true);
    shadow_desc.layout    = desc.layout;
    shadow_desc.index_type = .UINT16;
    shadow_desc.cull_mode  = .FRONT;
    shadow_desc.face_winding = .CCW;
    triles.shadow_pipeline = sg_make_pipeline(*shadow_desc);

    // Alpha keeps the nearest glass depth, so light shafts start at the window.
    glass_blend := MULTIPLY_BLEND;
    glass_blend.src_factor_alpha = .ONE;
    glass_blend.dst_factor_alpha = .ONE;
    glass_blend.op_alpha         = .MIN;
    glass_desc := pipeline_desc(trile_glass_shadow_shader_desc(sg_query_backend()), .SHADOW, glass_blend);
    glass_desc.colors[0].write_mask = .RGBA;
    glass_desc.layout       = desc.layout;
    glass_desc.index_type   = .UINT16;
    glass_desc.cull_mode    = .FRONT;
    glass_desc.face_winding = .CCW;
    triles.glass_shadow_pipeline = sg_make_pipeline(*glass_desc);

    for orientations {
        for r: 0..2  for c: 0..2  triles.params.orientations[it_index * 3 + r][c] = it.coef[r][c];
    }
    triles.palette_dirty = true;
}

renderer_trile_mesh_create :: (vertices: []Trile_Vertex, indices: []u16) -> u32 {
    id, mesh := slot_add(*triles.meshes);
    make_mesh(mesh, vertices, indices);
    return id;
}

renderer_trile_mesh_update :: (id: u32, vertices: []Trile_Vertex, indices: []u16) {
    mesh := slot_get(*triles.meshes, id);
    free_mesh(mesh);
    make_mesh(mesh, vertices, indices);
}

renderer_trile_mesh_destroy :: (id: u32) {
    free_mesh(slot_get(*triles.meshes, id));
    slot_remove(*triles.meshes, id);
}

renderer_swatch_set :: (id: u8, color: [3]u8, reflectivity: u8, gloss: u8, emittance: u8, glass: bool) {
    for 0..2  triles.palette[0][id][it] = color[it];
    triles.palette[0][id][3] = xx (min(cast(int) emittance, 127) * 255 / 127);   // emittance is 0..127
    triles.palette[1][id][0] = xx ifx glass then 255 else 0;
    triles.palette[1][id][1] = reflectivity;
    triles.palette[1][id][2] = gloss;
    triles.palette_dirty  = true;
}

triles_upload :: (scene: *Scene) {
    if triles.palette_dirty {
        triles.palette_dirty = false;
        if triles.palette_image.id  sg_destroy_image(triles.palette_image);
        desc := sg_image_desc.{ width = 256, height = 2, pixel_format = .RGBA8 };
        desc.data.subimage[0][0] = .{ triles.palette.data, size_of(type_of(triles.palette)) };
        triles.palette_image = sg_make_image(*desc);
    }

    array_reset_keeping_memory(*triles.instances);
    array_reset_keeping_memory(*triles.batches);

    draws : [..]Keyed(Instance);
    draws.allocator = temp;
    for view, view_index: scene.views {
        array_reset_keeping_memory(*draws);
        if view.draw_world {
            for chunk: scene.chunks  for group: chunk.groups  for group.instances {
                position := chunk.origin + Vector3.{xx it.x, xx it.y, xx it.z};
                cut := trile_cut(.{xx view_index}, group.mesh, position);
                array_add(*draws, .{group.mesh.id, .{position, xx it.orientation, 0, cut}});
            }
        }
        for scene.triles {
            if it.view.index != view_index  continue;
            preview : s64 = ifx it.tint != .NONE then PREVIEW_KEY else 0;
            cut := ifx preview then 0.0 else trile_cut(it.view, it.mesh, it.position);
            array_add(*draws, .{preview | it.mesh.id, .{it.position, xx it.orientation, xx it.tint, cut}});
        }
        batch_instances(view_index, draws, *triles.batches, *triles.instances);
    }
    stream_upload(*triles.stream, triles.instances);
}

// After every opaque caster, so glass behind something solid doesn't tint.
triles_draw_glass_shadow :: (pass: *Pass) {
    sg_apply_pipeline(triles.glass_shadow_pipeline);
    apply_uniforms(UB_view_params, *pass.params);
    triles.params.show_hidden = 1;
    apply_uniforms(UB_trile_params, *triles.params);
    for triles.batches {
        if it.view_index != pass.view_index || it.key & PREVIEW_KEY  continue;
        mesh := slot_get(*triles.meshes, xx it.key);
        if !mesh || mesh.index_count == 0  continue;
        bind : sg_bindings;
        bind.vertex_buffers[0]         = mesh.vertices;
        bind.index_buffer              = mesh.indices;
        bind.vertex_buffers[1]         = triles.stream.buffer;
        bind.vertex_buffer_offsets[1]  = it.first * size_of(Instance);
        bind.images[IMG_palette]       = triles.palette_image;
        bind.samplers[SMP_palette_smp] = samplers.nearest_clamp;
        sg_apply_bindings(*bind);
        sg_draw(0, mesh.index_count, it.count);
    }
}

triles_draw :: (pass: *Pass) {
    // Cut triles are only hidden from the camera itself, not from shadows or reflections.
    triles.params.show_hidden = xx (pass.kind != .MAIN);
    sg_apply_pipeline(ifx pass.kind == .SHADOW then triles.shadow_pipeline else triles.pipeline);
    apply_uniforms(UB_view_params, *pass.params);
    apply_uniforms(UB_trile_params, *triles.params);
    if pass.kind != .SHADOW {
        apply_uniforms(UB_shadow_params, *pass.shadow);
        fs_params := Trile_Fs_Params.{
            sun_dir           = pass.params.sun_direction,
            use_reflection    = xx (pass.kind == .MAIN),
            reflection_height = view_environment(pass.view).reflection_height,
        };
        probes_set_params(*fs_params);
        apply_uniforms(UB_trile_fs_params, *fs_params);
    }

    for triles.batches {
        if it.view_index != pass.view_index || (pass.kind != .MAIN && it.key & PREVIEW_KEY)  continue;
        mesh := slot_get(*triles.meshes, xx (it.key & ~PREVIEW_KEY));
        if !mesh || mesh.index_count == 0  continue;

        bind : sg_bindings;
        bind.vertex_buffers[0]         = mesh.vertices;
        bind.index_buffer              = mesh.indices;
        bind.vertex_buffers[1]         = triles.stream.buffer;
        bind.vertex_buffer_offsets[1]  = it.first * size_of(Instance);
        bind.images[IMG_palette]       = triles.palette_image;
        bind.samplers[SMP_palette_smp] = samplers.nearest_clamp;
        if pass.kind != .SHADOW {
            bind_shadow(pass, *bind);
            bind.images[IMG_trile_reflection]       = ifx pass.kind == .MAIN then view_reflection_image(pass.view_index) else texture_image(0);
            bind.images[IMG_trile_reflection_glow]  = ifx pass.kind == .MAIN then view_reflection_glow_image(pass.view_index) else texture_image(0);
            bind.samplers[SMP_trile_reflection_smp] = samplers.linear_clamp;
            probes_bind(*bind);
        }
        sg_apply_bindings(*bind);
        sg_draw(0, mesh.index_count, it.count);
    }
}

#scope_file

Mesh :: struct {
    vertices    : sg_buffer;
    indices     : sg_buffer;
    index_count : s32;
}

Instance :: struct {
    position    : Vector3;
    orientation : float;
    tint        : float;
    cut         : float;   // 0..1 dissolved away from the camera, still casts shadows
}

PREVIEW_KEY :: 1 << 32;

triles : struct {
    pipeline        : sg_pipeline;
    shadow_pipeline : sg_pipeline;
    glass_shadow_pipeline : sg_pipeline;
    params          : Trile_Params;
    meshes        : Slots(Mesh);

    palette       : [2][256][4]u8;   // row 0: colour, emittance; row 1: glass, reflectivity, gloss
    palette_image : sg_image;
    palette_dirty : bool;

    instances     : [..]Instance;
    batches       : [..]Batch;
    stream        : Stream_Buffer;
}

make_mesh :: (mesh: *Mesh, vertices: []Trile_Vertex, indices: []u16) {
    mesh.index_count = xx indices.count;
    if indices.count {
        mesh.vertices = sg_make_buffer(*(sg_buffer_desc.{ data = .{ vertices.data, xx (vertices.count * size_of(Trile_Vertex)) } }));
        mesh.indices  = sg_make_buffer(*(sg_buffer_desc.{ type = .INDEXBUFFER, data = .{ indices.data, xx (indices.count * size_of(u16)) } }));
    }
}

free_mesh :: (mesh: *Mesh) {
    if mesh.index_count {
        sg_destroy_buffer(mesh.vertices);
        sg_destroy_buffer(mesh.indices);
    }
    mesh.* = .{};
}
