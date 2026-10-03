WATER_HALF_SIZE :: 1000.0;

water_init :: () {
    backend := sg_query_backend();
    floor_desc := pipeline_desc(water_floor_shader_desc(backend), .VIEW_OPAQUE, depth_write = true);
    water.floor = sg_make_pipeline(*floor_desc);
    surface_desc := pipeline_desc(water_shader_desc(backend), .VIEW_TRANSPARENT, ALPHA_BLEND);
    water.surface = sg_make_pipeline(*surface_desc);
}

// The deep plane is opaque, so the surface can measure how much water lies above it.
water_draw_floor :: (pass: *Pass) {
    env := pass.view.environment;
    if pass.kind != .MAIN || !pass.view.draw_world || !env || !env.water  return;

    sg_apply_pipeline(water.floor);
    apply_uniforms(UB_view_params, *pass.params);
    vs := Water_Vs_Params.{ height = 0, half_size = WATER_HALF_SIZE };
    fs := Water_Floor_Params.{ floor_color = env.deep_color.component };
    apply_uniforms(UB_water_vs_params, *vs);
    apply_uniforms(UB_water_floor_params, *fs);
    sg_draw(0, 6, 1);
}

water_draw :: (pass: *Pass) {
    env := pass.view.environment;
    if pass.kind != .MAIN || !pass.view.draw_world || !env || !env.water  return;

    sg_apply_pipeline(water.surface);
    apply_uniforms(UB_view_params, *pass.params);
    apply_uniforms(UB_shadow_params, *pass.shadow);

    bind : sg_bindings;
    bind.images[IMG_reflection]       = view_reflection_image(pass.view_index);
    bind.images[IMG_normals]          = texture_image(env.water_normals.id);
    bind.images[IMG_reflection_glow]  = view_reflection_glow_image(pass.view_index);
    bind.samplers[SMP_reflection_smp] = samplers.linear_clamp;
    bind.samplers[SMP_normals_smp]    = samplers.linear_repeat;
    bind_shadow(pass, *bind);
    sg_apply_bindings(*bind);

    vs := Water_Vs_Params.{ height = env.reflection_height, half_size = WATER_HALF_SIZE };
    fs := Water_Fs_Params.{
        water_color   = env.water_color.component,
        sun_direction = env.sun_direction.component,
        shininess     = env.water_shininess,
        sun_color     = env.sun_color.component,
        time          = pass.scene.time,
        reflectivity  = env.water_reflectivity,
        distortion    = env.water_distortion,
    };
    apply_uniforms(UB_water_vs_params, *vs);
    apply_uniforms(UB_water_fs_params, *fs);
    sg_draw(0, 6, 1);
}

#scope_file

water : struct {
    floor   : sg_pipeline;
    surface : sg_pipeline;
}
