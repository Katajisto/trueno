camera: Camera;

trixel_count           : s32       = 0;
trixel_secondary_count : s32       = 0;
trixel_secondary_vbuf  : sg_buffer;
trixel_view_mode       : s32       = 0;
bypass_postprocess  : bool    = false;
bypass_shadows      : bool    = false;
bypass_reflections  : bool    = false;

trile_offsets : [..]s32;

current_world_config : *World_Config = null;
in_shadowmap_pass    : bool = false;
in_reflection_pass   : bool = false;
in_gbuffer_pass      : bool = false;
shadow_mvp           : Matrix4;

backend_handle_command :: (cmd: *Render_Command) {
    if cmd.type == {
        case .ADD_TRILE_POSITIONS;
            add_command := cast(*Render_Command_Add_Trile_Positions)cmd;
            backend_add_trile_positions(add_command.positions);
        case .DRAW_TRILE_POSITIONS;
            draw_command := cast(*Render_Command_Draw_Trile_Positions)cmd;
            backend_draw_trile_positions(draw_command.trile, draw_command.amount, draw_command.conf, draw_command.chunk_key, draw_command.preview_mode, draw_command.offset_index);
        case .DRAW_SKY;
            sky_command := cast(*Render_Command_Sky)cmd;
            backend_draw_sky(sky_command.worldConfig);
        case .SET_CAMERA;
            camera_command := cast(*Render_Command_Set_Camera)cmd;
            camera = camera_command.camera;
        case .DRAW_GROUND;
            ground_command := cast(*Render_Command_Draw_Ground)cmd;
            if in_gbuffer_pass {
                backend_draw_ground_gbuf(ground_command.worldConfig);
            } else {
                backend_draw_ground(ground_command.worldConfig);
            }
        case .UPDATE_TRIXELS;
            trixel_update_command := cast(*Render_Command_Update_Trixels)cmd;
            backend_update_trixels(trixel_update_command);
        case .DRAW_TRIXELS;
            draw_trixels_cmd := cast(*Render_Command_Draw_Trixels)cmd;
            backend_draw_trixels(draw_trixels_cmd.*);
        case .SET_LIGHT;
            set_light_command := cast(*Render_Command_Set_Light)cmd;
            current_world_config = set_light_command.worldConfig;
        case .DRAW_BILLBOARD;
            command := cast(*Render_Command_Draw_Billboard)cmd;
            if !in_gbuffer_pass {
                backend_draw_billboard(command.position, command.animation, command.frame, command.flipX);
            } else {
                backend_gbuffer_draw_billboard(command.position, command.animation, command.frame, command.flipX);
            }
        case .DRAW_PARTICLES;
            particles_cmd := cast(*Render_Command_Draw_Particles)cmd;
            backend_draw_particles(particles_cmd);
    }
}

backend_update_trixels :: (cmd: Render_Command_Update_Trixels) {
    if cmd.trile == null then return;

    trixels : [4096]Position_Color;
    count   : s32 = 0;

    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                if cmd.trile.trixels[x][y][z].empty then continue;

                trixels[count].pos.x = x * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                trixels[count].pos.y = y * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                trixels[count].pos.z = z * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                cm : Vector3 = .{1, 1, 1};
                if cmd.colMultipliers  cm = (cmd.colMultipliers.*)[x][y][z];
                trixels[count].pos.w = ifx (cm.x == 1.0 && cm.y == 1.0 && cm.z == 1.0) then 0.0 else 1.0;
                trixel_color := cmd.trile.trixels[x][y][z].material.color * cm;
                trixels[count].col = .{trixel_color.x, trixel_color.y, trixel_color.z, material_encode_to_float(cmd.trile.trixels[x][y][z].material)};
                count += 1;
            }
        }
    }

    range := sg_range.{ ptr = trixels.data, size = size_of(type_of(trixels)) };
    if cmd.is_secondary {
        trixel_secondary_count = count;
        sg_update_buffer(trixel_secondary_vbuf, *range);
    } else {
        trixel_count = count;
        sg_update_buffer(gPipelines.trixel.bind.vertex_buffers[2], *range);
    }
}

backend_draw_trixels :: (cmd: Render_Command_Draw_Trixels) {
    count := ifx cmd.is_secondary then trixel_secondary_count else trixel_count;
    if count == 0 then return;

    mvp := create_viewproj(*camera);
    vs_params : Vs_Params;
    vs_params.mvp           = mvp.floats;
    vs_params.camera        = camera.position.component;
    vs_params.world_offset  = cmd.world_offset.component;
    vs_params.tile_rotation = cmd.tile_rotation.floats;

    world_conf : Trixel_World_Config;
    wc : *World_Config = *(World_Config.{});
    world_config_to_shader_type(wc, *world_conf);

    fs_params : Trixel_Fs_Params;
    fs_params.view_mode  = trixel_view_mode;
    fs_params.brightness = cmd.brightness;

    bind := gPipelines.trixel.bind;
    if cmd.is_secondary  bind.vertex_buffers[2] = trixel_secondary_vbuf;

    sg_apply_pipeline(gPipelines.trixel.pipeline);
    sg_apply_bindings(*bind);
    sg_apply_uniforms(UB_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_apply_uniforms(UB_trixel_world_config, *(sg_range.{ptr = *world_conf, size = size_of(type_of(world_conf))}));
    sg_apply_uniforms(UB_trixel_fs_params, *(sg_range.{ ptr = *fs_params, size = size_of(type_of(fs_params)) }));
    sg_draw(0, 36, count);
}

backend_add_trile_positions :: (positions : []Vector4) {
    offset := sg_append_buffer(gPipelines.trile.bind.vertex_buffers[3], *(sg_range.{
        ptr = positions.data,
        size = size_of(Vector4) * cast(u64)positions.count,
    }));
    array_add(*trile_offsets, offset);
}

backend_draw_trile_positions :: (trile : string, amount : s32, worldConf: *World_Config, chunk_key: Chunk_Key, preview_mode: s32 = 0, offset_index: s32 = 0) {
    if in_gbuffer_pass {
        backend_draw_trile_positions_gbuffer(trile, amount, worldConf, offset_index);
    } else {
        backend_draw_trile_positions_main(trile, amount, worldConf, chunk_key, preview_mode, offset_index);
    }
}

backend_draw_trile_positions_gbuffer :: (trile : string, amount : s32, worldConf: *World_Config, offset_index: s32) {
    if offset_index >= trile_offsets.count then return;
    mvp := create_viewproj(*camera);
    view := create_lookat(*camera);
    vs_params : Gbuffer_Vs_Params;
    vs_params.mvp = mvp.floats;
    vs_params.view_matrix = view.floats;
    sg_apply_pipeline(gPipelines.gbuffer.pipeline);
    world_conf : Trile_World_Config;
    world_config_to_shader_type(worldConf, *world_conf);

    offset := trile_offsets[offset_index];

    trilegfx := get_trile_gfx(trile);
    bindings : sg_bindings;
    bindings.vertex_buffers[0]         = trilegfx.vertex_buffer;
    bindings.vertex_buffers[1]         = trilegfx.normal_buffer;
    bindings.vertex_buffers[2]         = trilegfx.centre_buffer;
    bindings.vertex_buffers[3]         = gPipelines.trile.bind.vertex_buffers[3];
    bindings.vertex_buffer_offsets[3]  = offset;
    bindings.samplers[0]               = gPipelines.trile.bind.samplers[0];
    bindings.images[0]                 = trilegfx.trixel_colors;

    sg_apply_bindings(*bindings);
    sg_apply_uniforms(UB_gbuffer_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params))}));
    sg_draw(0, cast(s32) trilegfx.vertex_count, amount);
}

backend_draw_trile_positions_main :: (trile : string, amount : s32, worldConf: *World_Config, chunk_key: Chunk_Key, preview_mode: s32 = 0, offset_index: s32 = 0) {
    start_frame_profiling_group("Draw trile positions");
    if offset_index >= trile_offsets.count {
        end_frame_profiling_group("Draw trile positions");
        return;
    }

    trilegfx := get_trile_gfx(trile);
    offset := trile_offsets[offset_index];

    if in_shadowmap_pass {
        vs_params : Trile_Shadow_Vs_Params;
        vs_params.mvp = shadow_mvp.floats;
        bindings : sg_bindings;
        bindings.vertex_buffers[0]        = trilegfx.vertex_buffer;
        bindings.vertex_buffers[1]        = trilegfx.normal_buffer;
        bindings.vertex_buffers[2]        = trilegfx.centre_buffer;
        bindings.vertex_buffers[3]        = gPipelines.trile.bind.vertex_buffers[3];
        bindings.vertex_buffer_offsets[3] = offset;
        sg_apply_pipeline(gPipelines.trile_shadow.pipeline);
        sg_apply_bindings(*bindings);
        sg_apply_uniforms(UB_trile_shadow_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
        sg_draw(0, cast(s32) trilegfx.vertex_count, amount);
        end_frame_profiling_group("Draw trile positions");
        return;
    }

    mvp := create_viewproj(*camera);
	vs_params : Trile_Vs_Params;
	vs_params.mvp = mvp.floats;
	vs_params.mvp_shadow = shadow_mvp.floats;
    vs_params.camera = camera.position.component;
    sg_apply_pipeline(gPipelines.trile.pipeline);
    world_conf : Trile_World_Config;
    world_config_to_shader_type(worldConf, *world_conf);
    world_conf.planeHeight = effective_plane_height(worldConf);

    bindings : sg_bindings;
    bindings.vertex_buffers[0]         = trilegfx.vertex_buffer;
    bindings.vertex_buffers[1]         = trilegfx.normal_buffer;
    bindings.vertex_buffers[2]         = trilegfx.centre_buffer;
    bindings.vertex_buffers[3]         = gPipelines.trile.bind.vertex_buffers[3];
    bindings.vertex_buffer_offsets[3]  = offset;
    bindings.samplers[0]               = gPipelines.trile.bind.samplers[0];
    bindings.images[0]                 = trilegfx.trixel_colors;
    bindings.images[1]                 = g_ssaobuf;
    bindings.samplers[2]               = g_shadowmap_sampler;
    bindings.images[2]                 = g_shadowmap;

    // Bind RDM textures for this chunk. Fall back to a 1x1 black image when
    // no baked data is available so sokol doesn't drop the draw call.
    // The shader gates all RDM sampling on atlas_rect.z > 0, which the
    // fallback texture returns as 0, so the ambient fallback path is taken.
    curworld := get_current_world();
    rdm_chunk := table_find_pointer(*curworld.world.chunks, chunk_key);
    if rdm_chunk != null && rdm_chunk.rdm_valid {
        bindings.images[3] = rdm_chunk.rdm_lookup;
        bindings.images[4] = rdm_chunk.rdm_atlas;
    } else {
        bindings.images[3] = g_rdm_fallback;
        bindings.images[4] = g_rdm_fallback;
    }
    bindings.images[5] = g_brdf_lut;
    bindings.samplers[3] = gPipelines.trile.bind.samplers[3];

    fs_params : Trile_Fs_Params;
    fs_params.mvp_shadow = shadow_mvp.floats;
    fs_params.is_reflection = ifx in_reflection_pass then cast(s32)1 else cast(s32)0;
    w, h := get_render_size();
    fs_params.screen_w = w;
    fs_params.screen_h = h;
    lc := *current_lighting_config;
    fs_params.rdm_enabled       = lc.rdm_enabled;
    fs_params.ambient_intensity = lc.ambient_intensity;
    fs_params.emissive_scale    = lc.emissive_scale;
    fs_params.rdm_diff_scale    = lc.rdm_diff_scale;
    fs_params.rdm_spec_scale    = lc.rdm_spec_scale;
    fs_params.ambient_color     = lc.ambient_color.component;
    fs_params.is_preview        = preview_mode;
    fs_params.rdm_tint               = lc.rdm_tint.component;
    fs_params.rdm_diff_saturation    = worldConf.rdmDiffSaturation;

    sg_apply_bindings(*bindings);
    sg_apply_uniforms(UB_trile_fs_params, *(sg_range.{ ptr = *fs_params, size = size_of(type_of(fs_params)) }));
    sg_apply_uniforms(UB_trile_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params))}));
    sg_apply_uniforms(UB_trile_world_config, *(sg_range.{ptr = *world_conf, size = size_of(type_of(world_conf))}));
    add_frame_profiling_point("After drawing setup");
    sg_draw(0, cast(s32) trilegfx.vertex_count, amount);
    end_frame_profiling_group("Draw trile positions");
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
    w, h := get_render_size();
    plane_data.mvp_shadow = shadow_mvp.floats;
    plane_data.screen_w = w;
    plane_data.screen_h = h;
    plane_data.cameraPosition = camera.position.component;
    plane_data.reflectionDistortion = 0.1;
    plane_data.shininess = wc.waterShininess;

    world_config_to_shader_type(wc, *world_conf);

    vs_params.mvp = mvp.floats;
    vs_params.planeHeight = effective_plane_height(wc);
    sg_apply_pipeline(gPipelines.plane.pipeline);
    gPipelines.plane.bind.samplers[1] = g_shadowmap_sampler;
    gPipelines.plane.bind.images[1] = g_shadowmap;
    sg_apply_bindings(*gPipelines.plane.bind);
    sg_apply_uniforms(UB_plane_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_apply_uniforms(UB_plane_world_config, *(sg_range.{ptr = *world_conf, size = size_of(type_of(world_conf))}));
    sg_apply_uniforms(UB_plane_data, *(sg_range.{ptr = *plane_data, size = size_of(type_of(plane_data))}));
    sg_draw(0, 6, 2);    
}

backend_draw_billboard :: (position: Vector3, anim: *Animation, frame_idx: s32, flipX: bool) {
    if !anim then return;
    mvp := create_viewproj(*camera);
    vs_params : Billboard_Vs_Params;
    gPipelines.billboard.bind.images[0] = anim.sheet;
    frame := anim.frames[frame_idx];
    vs_params.uvs = Vector4.{
        cast(float) frame.x / cast(float)anim.sheet_w,
        cast(float) frame.y / cast(float)anim.sheet_h,
        cast(float) frame.w / cast(float)anim.sheet_w,
        cast(float) frame.h / cast(float)anim.sheet_h,
    }.component;
    if flipX {
        vs_params.uvs[0] += vs_params.uvs[2];
        vs_params.uvs[2] *= -1.0;
    }
    vs_params.size = Vector2.{cast(float)(frame.w / 16), cast(float)(frame.h / 16)}.component;
    vs_params.cam = camera.position.component;
    if !in_shadowmap_pass {
        vs_params.mvp = mvp.floats;
    } else {
        vs_params.mvp = shadow_mvp.floats;
    }
    vs_params.offset = position.component;
    sg_apply_pipeline(gPipelines.billboard.pipeline);
    sg_apply_bindings(*gPipelines.billboard.bind);
    sg_apply_uniforms(UB_billboard_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_draw(0, 6, 1);    
}

backend_gbuffer_draw_billboard :: (position: Vector3, anim: *Animation, frame_idx: s32, flipX: bool) {
    if !anim then return;
    mvp := create_viewproj(*camera);
    view := create_lookat(*camera);
    vs_params : Gbuffer_Billboard_Vs_Params;
    vs_params.view_matrix = view.floats;
    gPipelines.gbuffer_billboard.bind.images[0] = anim.sheet;
    frame := anim.frames[frame_idx];
    vs_params.uvs = Vector4.{
        cast(float) frame.x / cast(float)anim.sheet_w,
        cast(float) frame.y / cast(float)anim.sheet_h,
        cast(float) frame.w / cast(float)anim.sheet_w,
        cast(float) frame.h / cast(float)anim.sheet_h,
    }.component;
    if flipX {
        vs_params.uvs[0] += vs_params.uvs[2];
        vs_params.uvs[2] *= -1.0;
    }
    vs_params.size = Vector2.{cast(float)(frame.w / 16), cast(float)(frame.h / 16)}.component;
    vs_params.cam = camera.position.component;
    if !in_shadowmap_pass {
        vs_params.mvp = mvp.floats;
    } else {
        vs_params.mvp = shadow_mvp.floats;
    }
    vs_params.offset = position.component;
    sg_apply_pipeline(gPipelines.gbuffer_billboard.pipeline);
    sg_apply_bindings(*gPipelines.gbuffer_billboard.bind);
    sg_apply_uniforms(UB_gbuffer_billboard_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_draw(0, 6, 1);    
}

backend_draw_particles :: (cmd: *Render_Command_Draw_Particles) {
    if cmd.count <= 0 then return;

    pip := ifx cmd.blend_mode == .ALPHA then *gPipelines.particle_alpha else *gPipelines.particle_additive;

    sg_update_buffer(pip.bind.vertex_buffers[1], *(sg_range.{
        ptr = cmd.pos_size.data,
        size = cast(u64)(cmd.count * size_of(Vector4)),
    }));
    sg_update_buffer(pip.bind.vertex_buffers[2], *(sg_range.{
        ptr = cmd.uv_rects.data,
        size = cast(u64)(cmd.count * size_of(Vector4)),
    }));
    sg_update_buffer(pip.bind.vertex_buffers[3], *(sg_range.{
        ptr = cmd.colors.data,
        size = cast(u64)(cmd.count * size_of(Vector4)),
    }));

    mvp := create_viewproj(*camera);
    vs_params : Particle_Vs_Params;
    vs_params.mvp = mvp.floats;
    vs_params.cam = camera.position.component;

    sg_apply_pipeline(pip.pipeline);
    pip.bind.images[IMG_particle_sprite] = cmd.sheet;
    sg_apply_bindings(*pip.bind);
    sg_apply_uniforms(UB_particle_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_draw(0, 6, cmd.count);
}

backend_draw_ground_gbuf :: (wc: *World_Config) {
    mvp := create_viewproj(*camera);
    view := create_lookat(*camera);
    vs_params : Gbuffer_Vs_Params;
    vs_params.mvp = mvp.floats;
    vs_params.view_matrix = view.floats;
    vs_params.isGround = 1;
    vs_params.planeHeight = effective_plane_height(wc);
    sg_apply_pipeline(gPipelines.gbuffer.pipeline);

    bindings : sg_bindings;
    bindings.vertex_buffers[0]         = g_plane_gbuffer_vertex_buffer;
    bindings.vertex_buffers[1]         = g_plane_gbuffer_normal_buffer;
    bindings.vertex_buffers[2]         = g_plane_gbuffer_center_buffer;
    bindings.vertex_buffers[3]         = g_plane_gbuffer_instance_buffer;

    sg_apply_bindings(*bindings);
    sg_apply_uniforms(UB_gbuffer_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params))}));
    sg_draw(0, 6, 1);
}

backend_process_command_buckets :: () {
    // 1. Set up textures and buffers.
    start_frame_profiling_group("Setup");
    for render_command_buckets.setup {
        backend_handle_command(it);
    } 
    end_frame_profiling_group("Setup");

    start_frame_profiling_group("Shadow pass");
    // 2. Shadow pass
    if current_world_config != null {
        shadow_mvp = create_shadow_viewproj(*camera, current_world_config);
        in_shadowmap_pass = true;
    	sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_shadowmap_attachments}));
        if !bypass_shadows {
            for render_command_buckets.shadow {
                backend_handle_command(it);
            }
        }
    	sg_end_pass();
        in_shadowmap_pass = false;
    }
    end_frame_profiling_group("Shadow pass");
    
    start_frame_profiling_group("Reflection pass");
    // 3. Reflection pass
	sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = gPipelines.plane.attachments}));
    if !bypass_reflections {
        in_reflection_pass = true;
        for render_command_buckets.reflection {
            backend_handle_command(it);
        }
        in_reflection_pass = false;
    }
	sg_end_pass();
    end_frame_profiling_group("Reflection pass");
    
    // 4. G-Buffer pass
    start_frame_profiling_group("G-Buffer pass");
    in_gbuffer_pass = true;
    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear_gbuf, attachments = g_gbuf_attachments}));
    for render_command_buckets.gbuffer {
        backend_handle_command(it);
    }
    sg_end_pass();
    in_gbuffer_pass = false;
    end_frame_profiling_group("G-Buffer pass");
     
    start_frame_profiling_group("SSAO pass");
    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_postprocess_attach_a }));
    sg_apply_pipeline(gPipelines.ssao.pipeline);
    gPipelines.ssao.bind.images[0] = g_gbuf_position;
    gPipelines.ssao.bind.images[1] = g_gbuf_normal;
    gPipelines.ssao.bind.images[2] = g_ssao_noise_buf;
    sg_apply_bindings(*gPipelines.ssao.bind);
    ssao_fs_uniform : Ssao_Fs_Params;
    mvp := create_perspective(*camera);
    ssao_fs_uniform.projection = mvp.floats;
    ssao_fs_uniform.samples    = g_ssao_samples;
    ssao_fs_uniform.ssao_power = current_post_process.ssao;
    sg_apply_uniforms(UB_ssao_fs_params, *(sg_range.{ ptr = *ssao_fs_uniform, size = size_of(type_of(ssao_fs_uniform)) }));
    sg_draw(0, 6, 1);    
    sg_end_pass();
    end_frame_profiling_group("SSAO pass");   

    start_frame_profiling_group("SSAO blur pass");
    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_ssao_attachments }));
    sg_apply_pipeline(gPipelines.op.pipeline);
    op_uniform : Op_Fs_Params;
    op_uniform.blur_size = current_post_process.ssao_size;
    op_uniform.op = 0;
    gPipelines.op.bind.images[0] = g_postprocess_a;
    sg_apply_uniforms(UB_op_fs_params, *(sg_range.{ ptr = *op_uniform, size = size_of(type_of(op_uniform)) }));
    sg_apply_bindings(*gPipelines.op.bind);
    sg_draw(0, 6, 1);    
    sg_end_pass();
    end_frame_profiling_group("SSAO blur pass");

    // 5. Main pass
    start_frame_profiling_group("Main pass");
	sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, attachments = g_rendertex_attachments}));
    for render_command_buckets.main {
        backend_handle_command(it);
    }
    debug_draw_flush_gpu();
	sg_end_pass();
    end_frame_profiling_group("Main pass");

    start_frame_profiling_group("Postprocess pass");
    if !bypass_postprocess {
        bloom_process();
        dof_process();
    }
    end_frame_profiling_group("Postprocess pass");

    start_frame_profiling_group("Final pass");
    // Begin drawing to swapchain
    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, swapchain = cast,force(sg_swapchain) sglue_swapchain() }));

    // Draw the render texture and do post processing:
    sg_apply_pipeline(gPipelines.postprocess.pipeline);
    gPipelines.postprocess.bind.images[0] = ifx bypass_postprocess then g_rendertex else g_postprocess_a;
    gPipelines.postprocess.bind.images[1] = LUT_list[g_current_lut_texture_index].image;
    sg_apply_bindings(*gPipelines.postprocess.bind);
    post_process_config_uniform : Post_Process_Config;
    if bypass_postprocess {
        neutral : Post_Process;
        neutral.tonemap = current_post_process.tonemap;
        fill_uniform_with_engine_data(*post_process_config_uniform, *neutral);
    } else {
        fill_uniform_with_engine_data(*post_process_config_uniform, *current_post_process);
    }
    sg_apply_uniforms(UB_post_process_config, *(sg_range.{ ptr = *post_process_config_uniform, size = size_of(type_of(post_process_config_uniform)) }));
    sg_draw(0, 6, 1);    

    sgl_defaults();
    sgl_matrix_mode_projection();
    sgl_ortho(0.0, sapp_widthf(), sapp_heightf(), 0.0, -1.0, +1.0);
    arb_tri_flush();

	sg_end_pass();
    end_frame_profiling_group("Final pass");

    sg_commit();

    array_reset_keeping_memory(*render_command_buckets.setup);
    array_reset_keeping_memory(*render_command_buckets.shadow);
    array_reset_keeping_memory(*render_command_buckets.reflection);
    array_reset_keeping_memory(*render_command_buckets.main);
    array_reset_keeping_memory(*render_command_buckets.gbuffer);
    array_reset_keeping_memory(*render_command_buckets.ui);
    array_reset_keeping_memory(*trile_offsets);
    current_world_config = null;
}
