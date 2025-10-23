dof_process :: () {
    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_postprocess_attach_a }));
    sg_apply_pipeline(gPipelines.op.pipeline);
    op_uniform_dilate : Op_Fs_Params;
    op_uniform_dilate.blur_size = current_post_process.dof_blur_size;
    op_uniform_dilate.op=2;
    gPipelines.op.bind.images[0] = g_rendertex;
    sg_apply_uniforms(UB_op_fs_params, *(sg_range.{ ptr = *op_uniform_dilate, size = size_of(type_of(op_uniform_dilate)) }));
    sg_apply_bindings(*gPipelines.op.bind);
    sg_draw(0, 6, 1);    
    sg_end_pass();

    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_postprocess_attach_b }));
    sg_apply_pipeline(gPipelines.op.pipeline);
    op_uniform_dof_blur : Op_Fs_Params;
    op_uniform_dof_blur.blur_size = current_post_process.dilate_size;
    op_uniform_dof_blur.separation = current_post_process.dilate_separation;
    op_uniform_dof_blur.dilate_min = current_post_process.dilate_min;
    op_uniform_dof_blur.dilate_max = current_post_process.dilate_max;
    op_uniform_dof_blur.op=1;
    gPipelines.op.bind.images[0] = g_postprocess_a;
    sg_apply_uniforms(UB_op_fs_params, *(sg_range.{ ptr = *op_uniform_dof_blur, size = size_of(type_of(op_uniform_dof_blur)) }));
    sg_apply_bindings(*gPipelines.op.bind);
    sg_draw(0, 6, 1);    
    sg_end_pass();

    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_postprocess_attach_a }));
    sg_apply_pipeline(gPipelines.mix.pipeline);
    mix_uniform : Mix_Fs_Params;
    mix_uniform.op = 0;
    mix_uniform.dof_min = current_post_process.dof_min;
    mix_uniform.dof_max = current_post_process.dof_max;
    mix_uniform.dof_point = current_post_process.dof_point;
    gPipelines.mix.bind.images[0] = g_postprocess_b;
    gPipelines.mix.bind.images[1] = g_rendertex;
    gPipelines.mix.bind.images[2] = g_gbuf_position;
    sg_apply_uniforms(UB_op_fs_params, *(sg_range.{ ptr = *mix_uniform, size = size_of(type_of(mix_uniform)) }));
    sg_apply_bindings(*gPipelines.mix.bind);
    sg_draw(0, 6, 1);    
    sg_end_pass();
}

