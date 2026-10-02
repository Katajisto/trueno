views_init :: () {
    desc := pipeline_desc(composite_shader_desc(sg_query_backend()), .SCREEN);
    views.composite = sg_make_pipeline(*desc);
}

view_begin_pass :: (index: int, width: s32, height: s32, reflection: bool) {
    if width != views.width || height != views.height {
        for views.targets {
            destroy_target(it.main);
            destroy_target(it.reflection);
        }
        array_reset_keeping_memory(*views.targets);
        views.width  = width;
        views.height = height;
    }
    while views.targets.count <= index  array_add(*views.targets, .{make_target(width, height), make_target(width, height)});
    targets := views.targets[index];

    action : sg_pass_action;
    action.colors[0] = .{ load_action = .CLEAR, clear_value = .{0, 0, 0, 1} };
    action.depth     = .{ load_action = .CLEAR, clear_value = 1 };
    target := ifx reflection then targets.reflection else targets.main;
    sg_begin_pass(*(sg_pass.{ action = action, attachments = target.attachments }));
}

view_reflection_image :: (index: int) -> sg_image {
    return views.targets[index].reflection.color;
}

view_composite :: (index: int) {
    sg_apply_pipeline(views.composite);
    params := Composite_Vs_Params.{ flip_y = ifx sg_query_features().origin_top_left then 1.0 else 0.0 };
    apply_uniforms(UB_composite_vs_params, *params);

    bind : sg_bindings;
    bind.images[IMG_view_color]       = views.targets[index].main.color;
    bind.samplers[SMP_composite_smp] = samplers.nearest_clamp;
    sg_apply_bindings(*bind);
    sg_draw(0, 3, 1);
}

#scope_file

View_Target :: struct {
    color       : sg_image;
    depth       : sg_image;
    attachments : sg_attachments;
}

views : struct {
    composite : sg_pipeline;
    targets   : [..]struct { main, reflection: View_Target; };
    width     : s32;
    height    : s32;
}

make_target :: (width: s32, height: s32) -> View_Target {
    t : View_Target;
    t.color = sg_make_image(*(sg_image_desc.{ render_target = true, width = width, height = height, pixel_format = VIEW_COLOR_FORMAT, sample_count = 1 }));
    t.depth = sg_make_image(*(sg_image_desc.{ render_target = true, width = width, height = height, pixel_format = VIEW_DEPTH_FORMAT, sample_count = 1 }));
    desc : sg_attachments_desc;
    desc.colors[0].image     = t.color;
    desc.depth_stencil.image = t.depth;
    t.attachments = sg_make_attachments(*desc);
    return t;
}

destroy_target :: (t: View_Target) {
    sg_destroy_attachments(t.attachments);
    sg_destroy_image(t.color);
    sg_destroy_image(t.depth);
}
