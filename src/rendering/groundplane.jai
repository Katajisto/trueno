draw_ground_plane :: (cam: *Camera, worldConfig: *World_Config = null) {
    mvp := create_viewproj(cam);
    vs_params : Plane_Vs_Params;

    world_conf : Plane_World_Config;
    plane_data : Plane_Data;

    w, h := get_window_size();
    plane_data.screen_w = w;
    plane_data.screen_h = h;
    plane_data.is_reflection_pass = xx ifx is_in_reflection_pass then 1 else 0;

    wc : *World_Config = ifx worldConfig == null then *(World_Config.{}) else worldConfig;

    world_config_to_shader_type(wc, *world_conf);

    vs_params.mvp = mvp.floats;
    sg_apply_pipeline(gPipelines.plane.pipeline);
    sg_apply_bindings(*gPipelines.plane.bind);
    sg_apply_uniforms(UB_plane_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_apply_uniforms(UB_plane_world_config, *(sg_range.{ptr = *world_conf, size = size_of(type_of(world_conf))}));
    sg_apply_uniforms(UB_plane_data, *(sg_range.{ptr = *plane_data, size = size_of(type_of(plane_data))}));
    
    sg_draw(0, 6, 1);    
}
