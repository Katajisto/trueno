sky_init :: () {
    desc := pipeline_desc(sky_shader_desc(sg_query_backend()), .VIEW_OPAQUE);
    desc.depth.compare = .ALWAYS;
    sky.pipeline = sg_make_pipeline(*desc);
}

sky_draw :: (pass: *Pass) {
    env := view_environment(pass.view);
    if !env.sky  return;
    params := Sky_Params.{
        sky_base     = .[env.sky_base.x,     env.sky_base.y,     env.sky_base.z,     0],
        sky_top      = .[env.sky_top.x,      env.sky_top.y,      env.sky_top.z,      0],
        sun_disk     = .[env.sun_disk.x,     env.sun_disk.y,     env.sun_disk.z,     0],
        sun_halo     = .[env.sun_halo.x,     env.sun_halo.y,     env.sun_halo.z,     0],
        horizon_halo = .[env.horizon_halo.x, env.horizon_halo.y, env.horizon_halo.z, 0],
        sun          = .[env.sun_direction.x, env.sun_direction.y, env.sun_direction.z, env.sky_intensity],
    };

    sg_apply_pipeline(sky.pipeline);
    apply_uniforms(UB_view_params, *pass.params);
    apply_uniforms(UB_sky_params, *params);
    sg_draw(0, 3, 1);
}

#scope_file

sky : struct {
    pipeline : sg_pipeline;
}
