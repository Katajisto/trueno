triles_init :: (orientations: [ORIENTATION_COUNT]Matrix3) {
    desc := pipeline_desc(trile_shader_desc(sg_query_backend()), .VIEW, depth_write = true);
    desc.layout.buffers[1].step_func = .PER_INSTANCE;
    desc.layout.attrs[ATTR_trile_position] = .{ format = .FLOAT3 };
    desc.layout.attrs[ATTR_trile_swatch]   = .{ format = .FLOAT };
    desc.layout.attrs[ATTR_trile_instance] = .{ format = .FLOAT4, buffer_index = 1 };
    desc.layout.attrs[ATTR_trile_tint]     = .{ format = .FLOAT,  buffer_index = 1 };
    desc.cull_mode    = .BACK;
    desc.face_winding = .CCW;
    triles.pipeline = sg_make_pipeline(*desc);

    for orientations {
        for r: 0..2  for c: 0..2  triles.params.orientations[it_index * 3 + r][c] = it.coef[r][c];
    }
    triles.palette_dirty = true;
}

renderer_trile_mesh_create :: (vertices: []Trile_Vertex) -> u32 {
    id, mesh := slot_add(*triles.meshes);
    make_mesh(mesh, vertices);
    return id;
}

renderer_trile_mesh_update :: (id: u32, vertices: []Trile_Vertex) {
    mesh := slot_get(*triles.meshes, id);
    free_mesh(mesh);
    make_mesh(mesh, vertices);
}

renderer_trile_mesh_destroy :: (id: u32) {
    free_mesh(slot_get(*triles.meshes, id));
    slot_remove(*triles.meshes, id);
}

renderer_swatch_set :: (id: u8, color: [3]u8, roughness: u8, metallic: u8, emittance: u8) {
    for 0..2  triles.palette[id][it] = color[it];
    triles.palette[id][3] = 255;
    triles.palette_dirty  = true;
}

triles_upload :: (scene: *Scene) {
    if triles.palette_dirty {
        triles.palette_dirty = false;
        if triles.palette_image.id  sg_destroy_image(triles.palette_image);
        desc := sg_image_desc.{ width = 256, height = 1, pixel_format = .RGBA8 };
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
                array_add(*draws, .{group.mesh.id, .{position, xx it.orientation, 0}});
            }
        }
        for scene.triles {
            if it.view.index != view_index  continue;
            preview : s64 = ifx it.tint != .NONE then PREVIEW_KEY else 0;
            array_add(*draws, .{preview | it.mesh.id, .{it.position, xx it.orientation, xx it.tint}});
        }
        batch_instances(view_index, draws, *triles.batches, *triles.instances);
    }
    stream_upload(*triles.stream, triles.instances);
}

triles_draw :: (pass: *Pass) {
    sg_apply_pipeline(triles.pipeline);
    apply_uniforms(UB_view_params, *pass.params);
    apply_uniforms(UB_trile_params, *triles.params);

    for triles.batches {
        if it.view_index != pass.view_index || (pass.reflection && it.key & PREVIEW_KEY)  continue;
        mesh := slot_get(*triles.meshes, xx (it.key & ~PREVIEW_KEY));
        if !mesh || mesh.vertex_count == 0  continue;

        bind : sg_bindings;
        bind.vertex_buffers[0]         = mesh.vertices;
        bind.vertex_buffers[1]         = triles.stream.buffer;
        bind.vertex_buffer_offsets[1]  = it.first * size_of(Instance);
        bind.images[IMG_palette]       = triles.palette_image;
        bind.samplers[SMP_palette_smp] = samplers.nearest_clamp;
        sg_apply_bindings(*bind);
        sg_draw(0, mesh.vertex_count, it.count);
    }
}

#scope_file

Mesh :: struct {
    vertices     : sg_buffer;
    vertex_count : s32;
}

Instance :: struct {
    position    : Vector3;
    orientation : float;
    tint        : float;
}

PREVIEW_KEY :: 1 << 32;

triles : struct {
    pipeline      : sg_pipeline;
    params        : Trile_Params;
    meshes        : Slots(Mesh);

    palette       : [256][4]u8;
    palette_image : sg_image;
    palette_dirty : bool;

    instances     : [..]Instance;
    batches       : [..]Batch;
    stream        : Stream_Buffer;
}

make_mesh :: (mesh: *Mesh, vertices: []Trile_Vertex) {
    mesh.vertex_count = xx vertices.count;
    if vertices.count {
        mesh.vertices = sg_make_buffer(*(sg_buffer_desc.{ data = .{ vertices.data, xx (vertices.count * size_of(Trile_Vertex)) } }));
    }
}

free_mesh :: (mesh: *Mesh) {
    if mesh.vertex_count  sg_destroy_buffer(mesh.vertices);
    mesh.* = .{};
}
