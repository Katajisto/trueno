sprites_init :: () {
    // Billboards and particles share the vertex shader, so they share attribute slots.
    make :: (shader: sg_shader_desc, target: Pipeline_Target, blend := sg_blend_state.{}) -> sg_pipeline {
        desc := pipeline_desc(shader, target, blend, depth_write = target != .VIEW_TRANSPARENT);
        desc.layout.buffers[0].step_func = .PER_INSTANCE;
        desc.layout.attrs[ATTR_sprite_center]  = .{ format = .FLOAT3 };
        desc.layout.attrs[ATTR_sprite_size]    = .{ format = .FLOAT2 };
        desc.layout.attrs[ATTR_sprite_uv_rect] = .{ format = .FLOAT4 };
        desc.layout.attrs[ATTR_sprite_face]    = .{ format = .FLOAT3 };
        desc.layout.attrs[ATTR_sprite_color]   = .{ format = .FLOAT4 };
        desc.layout.attrs[ATTR_sprite_glow]    = .{ format = .FLOAT };
        return sg_make_pipeline(*desc);
    }
    backend := sg_query_backend();
    sprites.pipelines[Kind.BILLBOARD]         = make(sprite_shader_desc(backend),   .VIEW_OPAQUE);
    sprites.pipelines[Kind.PARTICLE_ALPHA]    = make(particle_shader_desc(backend), .VIEW_TRANSPARENT, ALPHA_BLEND);
    sprites.pipelines[Kind.PARTICLE_ADDITIVE] = make(particle_shader_desc(backend), .VIEW_TRANSPARENT, ADDITIVE_BLEND);
    sprites.shadow_pipeline = make(sprite_shadow_shader_desc(backend), .SHADOW);
}

sprites_upload :: (scene: *Scene) {
    array_reset_keeping_memory(*sprites.instances);
    array_reset_keeping_memory(*sprites.batches);

    draws : [..]Keyed(Instance);
    draws.allocator = temp;
    for view_index: 0..scene.views.count-1 {
        array_reset_keeping_memory(*draws);
        for scene.billboards {
            if it.view.index != view_index  continue;
            array_add(*draws, .{key(.BILLBOARD, it.sheet), .{it.position, it.size, it.uv_rect, it.face, .{1, 1, 1, 1}, 0}});
        }
        for batch: scene.particles {
            if batch.view.index != view_index  continue;
            kind := ifx batch.blend == .ADDITIVE then Kind.PARTICLE_ADDITIVE else .PARTICLE_ALPHA;
            for batch.particles {
                array_add(*draws, .{key(kind, batch.sheet), .{it.position, .{it.size, it.size}, it.uv_rect, BILLBOARD_FACE_CAMERA, it.color, it.glow}});
            }
        }
        batch_instances(view_index, draws, *sprites.batches, *sprites.instances);
    }
    stream_upload(*sprites.stream, sprites.instances);
}

// Opaque sprites go before water, transparent ones after it. Only billboards cast shadows.
sprites_draw :: (pass: *Pass, transparent: bool) {
    shadow := pass.kind == .SHADOW;
    current : Kind = xx -1;
    for sprites.batches {
        if it.view_index != pass.view_index  continue;
        kind := cast(Kind) (it.key >> 32);
        if (kind != .BILLBOARD) != transparent  continue;

        if kind != current {
            current = kind;
            sg_apply_pipeline(ifx shadow then sprites.shadow_pipeline else sprites.pipelines[kind]);
            apply_uniforms(UB_view_params, *pass.params);
            params := Sprite_Params.{ lit = xx (kind == .BILLBOARD) };
            apply_uniforms(UB_sprite_params, *params);
            if kind == .BILLBOARD && !shadow  apply_uniforms(UB_shadow_params, *pass.shadow);
        }

        bind : sg_bindings;
        bind.vertex_buffers[0]        = sprites.stream.buffer;
        bind.vertex_buffer_offsets[0] = it.first * size_of(Instance);
        bind.images[IMG_sprite]       = texture_image(xx (it.key & 0xFFFF_FFFF));
        bind.samplers[SMP_sprite_smp] = samplers.nearest_clamp;
        if kind == .BILLBOARD && !shadow  bind_shadow(pass, *bind);
        sg_apply_bindings(*bind);
        sg_draw(0, 6, it.count);
    }
}

#scope_file

Kind :: enum {
    BILLBOARD;
    PARTICLE_ALPHA;
    PARTICLE_ADDITIVE;
}

Instance :: struct {
    center  : Vector3;
    size    : Vector2;
    uv_rect : Vector4;
    face    : Vector3;
    color   : Vector4;
    glow    : float;
}

sprites : struct {
    pipelines       : [#run enum_highest_value(Kind) + 1]sg_pipeline;
    shadow_pipeline : sg_pipeline;
    instances : [..]Instance;
    batches   : [..]Batch;
    stream    : Stream_Buffer;
}

key :: (kind: Kind, sheet: Texture) -> s64 {
    return (cast(s64) kind << 32) | sheet.id;
}
