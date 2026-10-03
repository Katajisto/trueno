BLOOM_LEVELS  :: 5;
BLOOM_SCATTER :: 0.7;

views_init :: () {
    backend := sg_query_backend();
    post_desc := pipeline_desc(post_shader_desc(backend), .SCREEN);
    views.post = sg_make_pipeline(*post_desc);
    glow_desc := pipeline_desc(bloom_glow_shader_desc(backend), .POST);
    views.bloom_glow = sg_make_pipeline(*glow_desc);
    down_desc := pipeline_desc(bloom_down_shader_desc(backend), .POST);
    views.bloom_down = sg_make_pipeline(*down_desc);
    // Each level becomes a blend toward the blurrier level below it, so the glow is
    // mostly wide blur rather than a copy of the bright pixels.
    up_desc := pipeline_desc(bloom_up_shader_desc(backend), .POST, sg_blend_state.{ enabled = true, src_factor_rgb = .BLEND_COLOR, dst_factor_rgb = .ONE_MINUS_BLEND_COLOR });
    up_desc.blend_color = .{ BLOOM_SCATTER, BLOOM_SCATTER, BLOOM_SCATTER, 1 };
    views.bloom_up = sg_make_pipeline(*up_desc);
}

view_begin_pass :: (index: int, width: s32, height: s32, kind: Pass_Kind, opaque: bool) {
    if width != views.width || height != views.height {
        for views.targets {
            destroy_target(it.main);
            destroy_target(it.reflection);
            for level: it.bloom {
                sg_destroy_attachments(level.attachments);
                sg_destroy_image(level.image);
            }
        }
        array_reset_keeping_memory(*views.targets);
        views.width  = width;
        views.height = height;
    }
    while views.targets.count <= index {
        targets := array_add(*views.targets);
        targets.main       = make_target(width, height);
        targets.reflection = make_target(width, height);
        w, h := width, height;
        for *level: targets.bloom {
            w, h = max(w / 2, 1), max(h / 2, 1);
            level.image = sg_make_image(*(sg_image_desc.{ render_target = true, width = w, height = h, pixel_format = VIEW_COLOR_FORMAT, sample_count = 1 }));
            desc : sg_attachments_desc;
            desc.colors[0].image = level.image;
            level.attachments = sg_make_attachments(*desc);
        }
    }
    targets := views.targets[index];

    target := ifx kind == .REFLECTION then targets.reflection else targets.main;
    action : sg_pass_action;
    if opaque {
        action.colors[0] = .{ load_action = .CLEAR, clear_value = .{0, 0, 0, 1} };
        action.colors[1] = .{ load_action = .CLEAR, clear_value = .{0, 0, 0, 0} };
        action.colors[2] = .{ load_action = .CLEAR, clear_value = .{1.0e4, 0, 0, 0} };
        action.depth     = .{ load_action = .CLEAR, clear_value = 1 };
        sg_begin_pass(*(sg_pass.{ action = action, attachments = target.opaque }));
    } else {
        action.colors[0] = .{ load_action = .LOAD };
        action.colors[1] = .{ load_action = .LOAD };
        action.depth     = .{ load_action = .LOAD };
        sg_begin_pass(*(sg_pass.{ action = action, attachments = target.transparent }));
    }
}

view_begin_shadow_pass :: (index: int) {
    while views.shadows.count <= index {
        shadow := array_add(*views.shadows);
        shadow.tint = sg_make_image(*(sg_image_desc.{ render_target = true, width = SHADOW_MAP_SIZE, height = SHADOW_MAP_SIZE, pixel_format = SHADOW_TINT_FORMAT, sample_count = 1 }));
        shadow.depth = sg_make_image(*(sg_image_desc.{ render_target = true, width = SHADOW_MAP_SIZE, height = SHADOW_MAP_SIZE, pixel_format = VIEW_DEPTH_FORMAT, sample_count = 1 }));
        desc : sg_attachments_desc;
        desc.colors[0].image     = shadow.tint;
        desc.depth_stencil.image = shadow.depth;
        shadow.attachments = sg_make_attachments(*desc);
    }
    action : sg_pass_action;
    action.depth = .{ load_action = .CLEAR, clear_value = 1 };
    action.colors[0] = .{ load_action = .CLEAR, clear_value = .{1, 1, 1, 1} };
    sg_begin_pass(*(sg_pass.{ action = action, attachments = views.shadows[index].attachments }));
}

view_shadow_image :: (index: int) -> sg_image {
    return views.shadows[index].depth;
}

view_shadow_tint_image :: (index: int) -> sg_image {
    return views.shadows[index].tint;
}

view_scene_image :: (index: int) -> sg_image {
    return views.targets[index].main.scene;
}

view_reflection_image :: (index: int) -> sg_image {
    return views.targets[index].reflection.color;
}

view_reflection_glow_image :: (index: int) -> sg_image {
    return views.targets[index].reflection.glow;
}

// Halves the glowing parts of the view down a chain of levels, then adds the
// levels back up, leaving the glow in the first level.
view_bloom :: (index: int) {
    targets := *views.targets[index];
    run :: (pipeline: sg_pipeline, source: sg_image, target: sg_attachments, load: bool) #expand {
        action : sg_pass_action;
        action.colors[0] = ifx load then sg_color_attachment_action.{ load_action = .LOAD } else .{ load_action = .DONTCARE };
        sg_begin_pass(*(sg_pass.{ action = action, attachments = target }));
        sg_apply_pipeline(pipeline);
        bind : sg_bindings;
        bind.images[IMG_bloom_source]  = source;
        bind.samplers[SMP_bloom_smp]   = samplers.linear_clamp;
        if pipeline.id == views.bloom_glow.id  bind.images[IMG_bloom_glow] = targets.main.glow;
        sg_apply_bindings(*bind);
        sg_draw(0, 3, 1);
        sg_end_pass();
    }

    run(views.bloom_glow, targets.main.color, targets.bloom[0].attachments, false);
    for 1..BLOOM_LEVELS-1  run(views.bloom_down, targets.bloom[it - 1].image, targets.bloom[it].attachments, false);
    for < 1..BLOOM_LEVELS-1  run(views.bloom_up, targets.bloom[it].image, targets.bloom[it - 1].attachments, true);
}

view_composite :: (index: int, env: Environment) {
    sg_apply_pipeline(views.post);
    params := Post_Params.{
        exposure     = env.exposure,
        contrast     = env.contrast,
        saturation   = env.saturation,
        bloom_amount = env.bloom_amount,
    };
    apply_uniforms(UB_post_params, *params);

    bind : sg_bindings;
    bind.images[IMG_view_color]       = views.targets[index].main.color;
    bind.images[IMG_bloom]            = views.targets[index].bloom[0].image;
    bind.samplers[SMP_view_smp]       = samplers.nearest_clamp;
    bind.samplers[SMP_bloom_view_smp] = samplers.linear_clamp;
    sg_apply_bindings(*bind);
    sg_draw(0, 3, 1);
}

#scope_file

View_Target :: struct {
    color       : sg_image;
    glow        : sg_image;
    scene       : sg_image;
    depth       : sg_image;
    opaque      : sg_attachments;
    transparent : sg_attachments;
}

views : struct {
    post       : sg_pipeline;
    bloom_glow : sg_pipeline;
    bloom_down : sg_pipeline;
    bloom_up   : sg_pipeline;
    targets    : [..]struct { main, reflection: View_Target; bloom: [BLOOM_LEVELS]struct { image: sg_image; attachments: sg_attachments; }; };
    shadows   : [..]struct { depth, tint: sg_image; attachments: sg_attachments; };
    width     : s32;
    height    : s32;
}

make_target :: (width: s32, height: s32) -> View_Target {
    t : View_Target;
    t.color = sg_make_image(*(sg_image_desc.{ render_target = true, width = width, height = height, pixel_format = VIEW_COLOR_FORMAT, sample_count = 1 }));
    t.glow  = sg_make_image(*(sg_image_desc.{ render_target = true, width = width, height = height, pixel_format = VIEW_GLOW_FORMAT,  sample_count = 1 }));
    t.scene = sg_make_image(*(sg_image_desc.{ render_target = true, width = width, height = height, pixel_format = VIEW_SCENE_FORMAT, sample_count = 1 }));
    t.depth = sg_make_image(*(sg_image_desc.{ render_target = true, width = width, height = height, pixel_format = VIEW_DEPTH_FORMAT, sample_count = 1 }));
    desc : sg_attachments_desc;
    desc.colors[0].image     = t.color;
    desc.colors[1].image     = t.glow;
    desc.depth_stencil.image = t.depth;
    t.transparent = sg_make_attachments(*desc);
    desc.colors[2].image = t.scene;
    t.opaque = sg_make_attachments(*desc);
    return t;
}

destroy_target :: (t: View_Target) {
    sg_destroy_attachments(t.opaque);
    sg_destroy_attachments(t.transparent);
    sg_destroy_image(t.color);
    sg_destroy_image(t.glow);
    sg_destroy_image(t.scene);
    sg_destroy_image(t.depth);
}
