bloom_process :: () {
    w, h := get_render_size();
    fw := cast(float)w;
    fh := cast(float)h;

    // Prefilter: threshold + downsample full-res → down_1 (w/2)
    {
        sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_bloom_down_1_attach }));
        sg_apply_pipeline(gPipelines.bloom_prefilter.pipeline);
        p : Bloom_Prefilter_Params;
        p.src_texel_x = 1.0 / fw;
        p.src_texel_y = 1.0 / fh;
        p.threshold   = current_post_process.bloom_treshold;
        gPipelines.bloom_prefilter.bind.images[IMG_bloom_prefilter_src] = g_rendertex;
        sg_apply_uniforms(UB_bloom_prefilter_params, *(sg_range.{ ptr = *p, size = size_of(type_of(p)) }));
        sg_apply_bindings(*gPipelines.bloom_prefilter.bind);
        sg_draw(0, 6, 1);
        sg_end_pass();
    }

    // Downsample chain
    bloom_downsample :: (src: sg_image, dst_attach: sg_attachments, src_w: float, src_h: float) {
        sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = dst_attach }));
        sg_apply_pipeline(gPipelines.bloom_downsample.pipeline);
        p : Bloom_Downsample_Params;
        p.src_texel_x = 1.0 / src_w;
        p.src_texel_y = 1.0 / src_h;
        gPipelines.bloom_downsample.bind.images[IMG_bloom_downsample_src] = src;
        sg_apply_uniforms(UB_bloom_downsample_params, *(sg_range.{ ptr = *p, size = size_of(type_of(p)) }));
        sg_apply_bindings(*gPipelines.bloom_downsample.bind);
        sg_draw(0, 6, 1);
        sg_end_pass();
    }
    bloom_downsample(g_bloom_down_1, g_bloom_down_2_attach, fw/2,  fh/2);
    bloom_downsample(g_bloom_down_2, g_bloom_down_3_attach, fw/4,  fh/4);
    bloom_downsample(g_bloom_down_3, g_bloom_down_4_attach, fw/8,  fh/8);

    // Upsample chain: tent(small) + large → dest
    bloom_upsample :: (small: sg_image, large: sg_image, dst_attach: sg_attachments, small_w: float, small_h: float) {
        sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = dst_attach }));
        sg_apply_pipeline(gPipelines.bloom_upsample.pipeline);
        p : Bloom_Upsample_Params;
        p.src_texel_x = 1.0 / small_w;
        p.src_texel_y = 1.0 / small_h;
        gPipelines.bloom_upsample.bind.images[IMG_bloom_upsample_small] = small;
        gPipelines.bloom_upsample.bind.images[IMG_bloom_upsample_large] = large;
        sg_apply_uniforms(UB_bloom_upsample_params, *(sg_range.{ ptr = *p, size = size_of(type_of(p)) }));
        sg_apply_bindings(*gPipelines.bloom_upsample.bind);
        sg_draw(0, 6, 1);
        sg_end_pass();
    }
    bloom_upsample(g_bloom_down_4, g_bloom_down_3, g_bloom_up_3_attach, fw/16, fh/16);
    bloom_upsample(g_bloom_up_3,   g_bloom_down_2, g_bloom_up_2_attach, fw/8,  fh/8);
    bloom_upsample(g_bloom_up_2,   g_bloom_down_1, g_bloom_up_1_attach, fw/4,  fh/4);
}

dof_downsample_process :: () {
    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_dof_downsample_attach }));
    sg_apply_pipeline(gPipelines.dof_downsample.pipeline);
    gPipelines.dof_downsample.bind.images[IMG_dof_downsample_src] = g_rendertex;
    sg_apply_bindings(*gPipelines.dof_downsample.bind);
    sg_draw(0, 6, 1);
    sg_end_pass();
}

dof_bokeh_process :: () {
    w, h := get_render_size();
    half_w := cast(float)(w / 2);
    half_h := cast(float)(h / 2);
    radius  := current_post_process.dof_blur_size * 3.0;
    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_dof_attach }));
    sg_apply_pipeline(gPipelines.dof_blur.pipeline);
    params : Dof_Blur_Params;
    params.bokeh_radius_x = radius / half_w;
    params.bokeh_radius_y = radius / half_h;
    gPipelines.dof_blur.bind.images[IMG_dof_blur_src] = g_dof_downsample_tex;
    sg_apply_uniforms(UB_dof_blur_params, *(sg_range.{ ptr = *params, size = size_of(type_of(params)) }));
    sg_apply_bindings(*gPipelines.dof_blur.bind);
    sg_draw(0, 6, 1);
    sg_end_pass();
}
