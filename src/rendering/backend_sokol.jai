camera: Camera;

backend_handle_command :: (cmd: *Render_Command) {
    if cmd.type == {
        case .DRAW_SKY;
            sky_command := cast(*Render_Command_Sky)cmd;
            backend_draw_sky(sky_command.worldConfig);
        case .SET_CAMERA;
            camera_command := cast(*Render_Command_Set_Camera)cmd;
            camera = camera_command.camera;
        case .GENERATE_GROUND;
            gen_command := cast(*Render_Command_Generate_Ground_Texture)cmd;
            update_image_from_ground(gen_command.world, *gPipelines.plane.bind.images[1]);
        case .DRAW_GROUND;
            ground_command := cast(*Render_Command_Draw_Ground)cmd;
            backend_draw_ground(ground_command.worldConfig);

    }
}

backend_draw_sky :: (wc: *World_Config) {
    mvp := create_viewproj(*camera);
    vs_params : Sky_Vs_Params;

    world_conf : Sky_World_Config;

    world_config_to_shader_type(wc, *world_conf);

    vs_params.mvp = mvp.floats;
    sg_apply_pipeline(gPipelines.sky.pipeline);
    sg_apply_bindings(*gPipelines.sky.bind);
    sg_apply_uniforms(UB_sky_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_apply_uniforms(UB_sky_world_config, *(sg_range.{ptr = *world_conf, size = size_of(type_of(world_conf))}));
    sg_draw(0, 36, 1);
}

backend_draw_ground :: (wc: *World_Config) {
    mvp := create_viewproj(*camera);
    vs_params : Plane_Vs_Params;
    world_conf : Plane_World_Config;
    plane_data : Plane_Data;
    w, h := get_window_size();
    plane_data.screen_w = w;
    plane_data.screen_h = h;

    world_config_to_shader_type(wc, *world_conf);

    vs_params.mvp = mvp.floats;
    sg_apply_pipeline(gPipelines.plane.pipeline);
    sg_apply_bindings(*gPipelines.plane.bind);
    sg_apply_uniforms(UB_plane_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_apply_uniforms(UB_plane_world_config, *(sg_range.{ptr = *world_conf, size = size_of(type_of(world_conf))}));
    sg_apply_uniforms(UB_plane_data, *(sg_range.{ptr = *plane_data, size = size_of(type_of(plane_data))}));
    sg_draw(0, 6, 1);    
}

backend_process_command_buckets :: () {
    // 1. Set up textures and buffers.
    for render_command_buckets.setup {
        backend_handle_command(it);
    } 

    // 2. Reflection pass
	sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = gPipelines.plane.attachments}));
    for render_command_buckets.reflection {
        backend_handle_command(it);
    }    
	sg_end_pass();

    // 3. Main pass
    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, swapchain = cast,force(sg_swapchain) sglue_swapchain() }));
    for render_command_buckets.main {
        backend_handle_command(it);
    }
    // 3.2 Draw the UI. @ToDo: This should probably happen after post processing once we have that.
    // Also, it's kind of stupid that this has it's own command system. It should be moved to using the
    // same backend commands we are using for other rendering.
    sgl_defaults();
    sgl_matrix_mode_projection();
    sgl_ortho(0.0, sapp_widthf(), sapp_heightf(), 0.0, -1.0, +1.0);
    arb_tri_flush();

    // End the main pass
	sg_end_pass();


    sg_commit();

    array_reset_keeping_memory(*render_command_buckets.setup);
    array_reset_keeping_memory(*render_command_buckets.shadow);
    array_reset_keeping_memory(*render_command_buckets.reflection);
    array_reset_keeping_memory(*render_command_buckets.main);
    array_reset_keeping_memory(*render_command_buckets.ui);
}
