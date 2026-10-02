WATER_HALF_SIZE :: 1000.0;

water_init :: () {
    desc := pipeline_desc(water_shader_desc(sg_query_backend()), .VIEW, blend = true);
    water.pipeline = sg_make_pipeline(*desc);
}

water_draw :: (pass: *Pass) {
    env := pass.view.environment;
    if pass.reflection || !pass.view.draw_world || !env || !env.water  return;

    sg_apply_pipeline(water.pipeline);
    apply_uniforms(UB_view_params, *pass.params);

    bind : sg_bindings;
    bind.images[IMG_reflection]       = view_reflection_image(pass.view_index);
    bind.images[IMG_normals]          = texture_image(env.water_normals.id);
    bind.samplers[SMP_reflection_smp] = samplers.linear_clamp;
    bind.samplers[SMP_normals_smp]    = samplers.linear_repeat;
    sg_apply_bindings(*bind);

    draw_plane :: (height: float, color: Vector3, surface: bool) #expand {
        vs := Water_Vs_Params.{ height = height, half_size = WATER_HALF_SIZE };
        fs := Water_Fs_Params.{
            color        = color.component,
            surface      = xx surface,
            reflectivity = env.water_reflectivity,
            distortion   = env.water_distortion,
        };
        apply_uniforms(UB_water_vs_params, *vs);
        apply_uniforms(UB_water_fs_params, *fs);
        sg_draw(0, 6, 1);
    }
    draw_plane(0, env.deep_color, false);
    draw_plane(env.reflection_height, env.water_color, true);
}

#scope_file

water : struct {
    pipeline : sg_pipeline;
}
