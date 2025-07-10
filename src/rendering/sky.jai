draw_sky :: (cam: *Camera) {
    mvp := create_viewproj(cam);
    vs_params : Sky_Vs_Params;
    vs_params.mvp = mvp.floats;
    sg_apply_pipeline(gPipelines.sky.pipeline);
    sg_apply_bindings(*gPipelines.sky.bind);
    sg_apply_uniforms(UB_sky_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_draw(0, 36, 1);    
}
