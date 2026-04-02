SHADOWMAP_SIZE :: 1000;

Pipeline_Binding :: struct {
    pipeline    : sg_pipeline;
    bind        : sg_bindings;
    attachments : sg_attachments;
    pass_action : sg_pass_action;
}

g_specular_lut  : sg_image;
g_brdf_lut      : sg_image;
g_rdm_fallback  : sg_image; // 1x1 black image used when a chunk has no baked RDM data

g_shadowmap             : sg_image;
g_shadowmap_img         : sg_image;
g_shadowmap_attachments : sg_attachments;
g_shadowmap_sampler     : sg_sampler;

g_rendertex             : sg_image;
g_rendertex_depth       : sg_image;
g_rendertex_attachments : sg_attachments;

g_gbuf_position         : sg_image;
g_gbuf_normal           : sg_image;
g_gbuf_depth            : sg_image;
g_gbuf_attachments      : sg_attachments;

g_ssaobuf               : sg_image;
g_ssao_noise_buf        : sg_image;
g_ssaobuf_depth         : sg_image;
g_ssao_attachments      : sg_attachments;

g_postprocess_a         : sg_image;
g_postprocess_b         : sg_image;
g_postprocess_a_depth   : sg_image;
g_postprocess_b_depth   : sg_image;
g_postprocess_attach_a  : sg_attachments;
g_postprocess_attach_b  : sg_attachments;
  

gPipelines : struct {
    // G-Buffer generation for SSAO and other effects
    gbuffer: Pipeline_Binding;

    // Arbitrary triangle rendering for rendering 2D things on the screen.
    // Used for UI rendering.
    arbtri : Pipeline_Binding;

    // Trixel rendering. Used for Trile editor rendering, in-game triles are rendered from
    // generated meshes.
    trixel : Pipeline_Binding;

    // Sky rendering.
    sky    : Pipeline_Binding;

    // Renders sets of triles
    trile  : Pipeline_Binding;

    // Depth-only shadow pass for triles (no lighting/RDM)
    trile_shadow : Pipeline_Binding;

    // Renders the ground plane. (just water)
    plane  : Pipeline_Binding;

    // Post-processing pipeline
    postprocess : Pipeline_Binding;

    op : Pipeline_Binding;
    
    mix : Pipeline_Binding;
    
    billboard : Pipeline_Binding;
    
    gbuffer_billboard : Pipeline_Binding;

    particle_additive : Pipeline_Binding;
    particle_alpha    : Pipeline_Binding;

    ssao: Pipeline_Binding;

    debugline : Pipeline_Binding;
}

create_final_image :: () {
    // @ToDo: Some smarter logic for this.
    w,h := get_render_size();


    if g_rendertex.id != INVALID_ID then sg_destroy_image(g_rendertex);
    if g_rendertex_depth.id != INVALID_ID then sg_destroy_image(g_rendertex_depth);

    img_desc := sg_image_desc.{
        width = w,
        height = h,
        pixel_format = .RGBA32F,
        render_target = true,
    };
    depth_desc := sg_image_desc.{
        width = w,
        height = h,
        pixel_format = .DEPTH,
        render_target = true,
    };
    g_rendertex = sg_make_image(*img_desc);
    g_rendertex_depth = sg_make_image(*depth_desc);
    attachmentsDesc : sg_attachments_desc;
	attachmentsDesc = .{
	    colors[0].image = g_rendertex,
	   	depth_stencil.image = g_rendertex_depth,
	};
    sg_destroy_attachments(g_rendertex_attachments);
    g_rendertex_attachments = sg_make_attachments(*attachmentsDesc);
}

create_shadowmap_image :: () {
    w : s32 = SHADOWMAP_SIZE;
    h : s32 = SHADOWMAP_SIZE;

    if g_shadowmap.id != INVALID_ID then sg_destroy_image(g_shadowmap);

    depth_desc := sg_image_desc.{
        width = w,
        height = h,
        pixel_format = .DEPTH,
        render_target = true,
    };
    img_desc := sg_image_desc.{
        width = w,
        height = h,
        pixel_format = .RGBA32F,
        render_target = true,
    };
    g_shadowmap = sg_make_image(*depth_desc);
    g_shadowmap_img = sg_make_image(*img_desc);
    attachmentsDesc : sg_attachments_desc;
	attachmentsDesc = .{
	    colors[0].image = g_shadowmap_img,
	   	depth_stencil.image = g_shadowmap,
	};
    sg_destroy_attachments(g_shadowmap_attachments);
    g_shadowmap_attachments = sg_make_attachments(*attachmentsDesc);
}

create_pipelines :: () {
    create_gbuffer_images();
    create_gbuffer_pipeline();
    create_arbtri_pipeline();
    create_trixel_pipeline();
    create_trile_pipeline();
    create_trile_shadow_pipeline();
    create_sky_pipeline();
    create_plane_pipeline();
    create_postprocess_pipeline();
    create_ssao_pipeline();
    create_op_pipeline();
    create_mix_pipeline();
    create_billboard_pipeline();
    create_gbuffer_billboard_pipeline();
    create_particle_pipeline();
    create_debugline_pipeline();

    create_shadowmap_image();
    create_final_image();
    create_ssao_images();
    create_gbuffer_impostors();
}

create_gbuffer_images :: () {
    w,h := get_render_size();

    if g_gbuf_position.id != INVALID_ID then sg_destroy_image(g_gbuf_position);
    if g_gbuf_normal.id != INVALID_ID then sg_destroy_image(g_gbuf_normal);
    if g_gbuf_depth.id != INVALID_ID then sg_destroy_image(g_gbuf_depth);

    img_desc := sg_image_desc.{
        width = w,
        height = h,
        pixel_format = .RGBA16F,
        render_target = true,
    };
    depth_desc := sg_image_desc.{
        width = w,
        height = h,
        pixel_format = .DEPTH,
        render_target = true,
    };

    g_gbuf_position = sg_make_image(*img_desc);
    g_gbuf_normal = sg_make_image(*img_desc);
    g_gbuf_depth = sg_make_image(*depth_desc);

    attachmentsDesc : sg_attachments_desc;
	attachmentsDesc = .{
	    colors[0].image = g_gbuf_position,
	    colors[1].image = g_gbuf_normal,
	   	depth_stencil.image = g_gbuf_depth,
	};
    sg_destroy_attachments(g_gbuf_attachments);
    g_gbuf_attachments = sg_make_attachments(*attachmentsDesc);
}

TRIXEL_SIZE_HALF : float : 1.0/32.0;
TRIXEL_SIZE      : float : 1.0/16.0;

gArbtriMem : [100000*3*9]float;

Position_Color :: struct {
    pos: Vector4;
    col: Vector4;
}

create_trixel_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := trixel_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.buffers[0].stride = 4*3;
    pipeline.layout.buffers[1].stride = 4*3;
    pipeline.layout.buffers[2].step_func = .PER_INSTANCE;

    pipeline.layout.attrs[ATTR_trixel_position] = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.layout.attrs[ATTR_trixel_normal]   = .{ format = .FLOAT3, buffer_index = 1 };
    pipeline.layout.attrs[ATTR_trixel_inst]     = .{ format = .FLOAT4, buffer_index = 2 };
    pipeline.layout.attrs[ATTR_trixel_inst_col] = .{ format = .FLOAT4, buffer_index = 2 };
    pipeline.index_type = .UINT16;
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
            pixel_format = .DEPTH,
    };

    color_state := sg_color_target_state.{
        pixel_format = .RGBA32F,
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        }

    };

    vertices : [24]Vector3 = .[
        .{-TRIXEL_SIZE/2, -TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, -TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, -TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, -TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, -TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, -TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, -TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, -TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, -TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{TRIXEL_SIZE/2, -TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, -TRIXEL_SIZE/2, -TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, -TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, TRIXEL_SIZE/2, TRIXEL_SIZE/2},
        .{-TRIXEL_SIZE/2, TRIXEL_SIZE/2, -TRIXEL_SIZE/2}
    ];

    normals : [24]Vector3 = .[
        .{0.0, 0.0, 1.0},
        .{0.0, 0.0, 1.0},
        .{0.0, 0.0, 1.0},
        .{0.0, 0.0, 1.0},
        .{0.0, 0.0,-1.0},
        .{0.0, 0.0,-1.0},
        .{0.0, 0.0,-1.0},
        .{0.0, 0.0,-1.0},
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
        .{0.0,-1.0, 0.0},
        .{0.0,-1.0, 0.0},
        .{0.0,-1.0, 0.0},
        .{0.0,-1.0, 0.0},
        .{1.0, 0.0, 0.0},
        .{1.0, 0.0, 0.0},
        .{1.0, 0.0, 0.0},
        .{1.0, 0.0, 0.0},
        .{-1.0, 0.0, 0.0},
        .{-1.0, 0.0, 0.0},
        .{-1.0, 0.0, 0.0},
        .{-1.0, 0.0, 0.0}
    ];

    k : u16 = 0;
    i : u16 = 0;

    indices : [36]u16;

    while i < 36 {
        indices[i] = 4*k;
        indices[i + 1] = 4*k + 1;
        indices[i + 2] = 4*k + 2;
        indices[i + 3] = 4*k;
        indices[i + 4] = 4*k + 2;
        indices[i + 5] = 4*k + 3;
        k += 1;
        i += 6;
    }


    pipeline.color_count = 1;
    pipeline.colors[0]   = color_state;

    gPipelines.trixel.pipeline = sg_make_pipeline(*pipeline);

    ibuffer         := sg_buffer_desc.{ type = .INDEXBUFFER, data = .{ ptr = indices.data, size = 36 * 2 } };
    vbuffer         := sg_buffer_desc.{ data = .{ ptr = vertices.data, size = 24 * 3 * 4 } };
    nbuffer         := sg_buffer_desc.{ data = .{ ptr = normals.data, size = 24 * 3 * 4 } };
    instance_buffer := sg_buffer_desc.{ usage = .STREAM, size = 4096 * size_of(Position_Color)};

    gPipelines.trixel.bind.index_buffer      = sg_make_buffer(*ibuffer);
    gPipelines.trixel.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);
    gPipelines.trixel.bind.vertex_buffers[1] = sg_make_buffer(*nbuffer);
    gPipelines.trixel.bind.vertex_buffers[2] = sg_make_buffer(*instance_buffer);

    secondary_instance_buffer := sg_buffer_desc.{ usage = .STREAM, size = 4096 * size_of(Position_Color)};
    trixel_secondary_vbuf = sg_make_buffer(*secondary_instance_buffer);
}

create_gbuffer_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := gbuffer_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.buffers[0].stride = 4*3;
    pipeline.layout.buffers[1].stride = 4*3;

    pipeline.layout.buffers[3].step_func = .PER_INSTANCE;

    instance_buffer := sg_buffer_desc.{ usage = .STREAM, size = 16 * 4096 * 4 * 4};

    pipeline.layout.attrs[ATTR_trile_position] = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.layout.attrs[ATTR_trile_normal]   = .{ format = .FLOAT3, buffer_index = 1 };
    pipeline.layout.attrs[ATTR_trile_centre]   = .{ format = .FLOAT3, buffer_index = 2 };
    pipeline.layout.attrs[ATTR_trile_instance] = .{ format = .FLOAT4, buffer_index = 3 };
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
            pixel_format = .DEPTH,
    };

    color_state_pos := sg_color_target_state.{
        pixel_format = .RGBA16F,
    };
    color_state_normal := sg_color_target_state.{
        pixel_format = .RGBA16F,
    };


    pipeline.color_count = 2;
    pipeline.colors[0]   = color_state_pos;
    pipeline.colors[1]   = color_state_normal;

    gPipelines.gbuffer.pipeline = sg_make_pipeline(*pipeline);
    gPipelines.gbuffer.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));
    gPipelines.gbuffer.bind.vertex_buffers[3] = sg_make_buffer(*instance_buffer);
}

create_trile_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := trile_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.buffers[0].stride = 4*3;
    pipeline.layout.buffers[1].stride = 4*3;

    pipeline.layout.buffers[3].step_func = .PER_INSTANCE;

    instance_buffer := sg_buffer_desc.{ usage = .STREAM, size = 16 * 4096 * 4 * 4};

    pipeline.layout.attrs[ATTR_trile_position] = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.layout.attrs[ATTR_trile_normal]   = .{ format = .FLOAT3, buffer_index = 1 };
    pipeline.layout.attrs[ATTR_trile_centre]   = .{ format = .FLOAT3, buffer_index = 2 };
    pipeline.layout.attrs[ATTR_trile_instance] = .{ format = .FLOAT4, buffer_index = 3 };
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
            pixel_format = .DEPTH,
    };

    color_state := sg_color_target_state.{
        pixel_format = .RGBA32F,
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        }
    };


    pipeline.color_count = 1;
    pipeline.colors[0]   = color_state;

    gPipelines.trile.pipeline = sg_make_pipeline(*pipeline);
    gPipelines.trile.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));
    gPipelines.trile.bind.vertex_buffers[3] = sg_make_buffer(*instance_buffer);
    gPipelines.trile.bind.samplers[3] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
    }));
}

create_trile_shadow_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := trile_shadow_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.buffers[0].stride = 4*3;
    pipeline.layout.buffers[1].stride = 4*3;
    pipeline.layout.buffers[3].step_func = .PER_INSTANCE;
    // Explicit locations matching layout(location=N) in the shader.
    pipeline.layout.attrs[0] = .{ format = .FLOAT3, buffer_index = 0 }; // position
    pipeline.layout.attrs[1] = .{ format = .FLOAT3, buffer_index = 1 }; // normal (slot match)
    pipeline.layout.attrs[2] = .{ format = .FLOAT3, buffer_index = 2 }; // centre (slot match)
    pipeline.layout.attrs[3] = .{ format = .FLOAT4, buffer_index = 3 }; // instance
    pipeline.depth = .{
        write_enabled = true,
        compare       = .LESS_EQUAL,
        pixel_format  = .DEPTH,
    };
    pipeline.color_count = 1;
    pipeline.colors[0].pixel_format = .RGBA32F;
    gPipelines.trile_shadow.pipeline = sg_make_pipeline(*pipeline);
}

create_sky_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := sky_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.buffers[0].stride = 4*3;

    pipeline.layout.attrs[ATTR_sky_position] = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.index_type = .UINT16;
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
            pixel_format = .DEPTH,
    };

    color_state := sg_color_target_state.{
        pixel_format = .RGBA32F,
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        }
    };


    vertices : [24]Vector3 = .[
        .{-1, -1, 1},
        .{1, -1, 1},
        .{1, 1, 1},
        .{-1, 1, 1},
        .{-1, -1, -1},
        .{-1, 1, -1},
        .{1, 1, -1},
        .{1, -1, -1},
        .{-1, 1, -1},
        .{-1, 1, 1},
        .{1, 1, 1},
        .{1, 1, -1},
        .{-1, -1, -1},
        .{1, -1, -1},
        .{1, -1, 1},
        .{-1, -1, 1},
        .{1, -1, -1},
        .{1, 1, -1},
        .{1, 1, 1},
        .{1, -1, 1},
        .{-1, -1, -1},
        .{-1, -1, 1},
        .{-1, 1, 1},
        .{-1, 1, -1}
    ];

    k : u16 = 0;
    i : u16 = 0;

    indices : [36]u16;

    while i < 36 {
        indices[i] = 4*k;
        indices[i + 1] = 4*k + 1;
        indices[i + 2] = 4*k + 2;
        indices[i + 3] = 4*k;
        indices[i + 4] = 4*k + 2;
        indices[i + 5] = 4*k + 3;
        k += 1;
        i += 6;
    }


    pipeline.color_count = 1;
    pipeline.colors[0]   = color_state;

    gPipelines.sky.pipeline = sg_make_pipeline(*pipeline);

    ibuffer         := sg_buffer_desc.{ type = .INDEXBUFFER, data = .{ ptr = indices.data, size = 36 * 2 } };
    vbuffer         := sg_buffer_desc.{ data = .{ ptr = vertices.data, size = 24 * 3 * 4 } };

    gPipelines.sky.bind.index_buffer      = sg_make_buffer(*ibuffer);
    gPipelines.sky.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);
}

create_plane_pipeline_reflection_images :: () {
    binding := *gPipelines.plane.bind;
    if binding.images[4].id != INVALID_ID then sg_destroy_image(binding.images[4]);
    if binding.images[5].id != INVALID_ID then sg_destroy_image(binding.images[5]);
    if binding.images[0].id != INVALID_ID then sg_destroy_image(binding.images[0]);

    w, h := get_render_size();
    img_desc := sg_image_desc.{
        width = w/2,
        height = h/2,
        pixel_format = .RGBA32F,
        render_target = true,
    };
    depth_desc := sg_image_desc.{
        width = w/2,
        height = h/2,
        pixel_format = .DEPTH,
        render_target = true,
    };
    binding.images[4] = sg_make_image(*img_desc);
    img_desc.sample_count = 1;
    binding.images[0] = sg_make_image(*img_desc);
    binding.images[5] = sg_make_image(*depth_desc);

    attachmentsDesc : sg_attachments_desc;
	attachmentsDesc = .{
	    colors[0].image = gPipelines.plane.bind.images[0],
	   	depth_stencil.image = gPipelines.plane.bind.images[5],
	};

    sg_destroy_attachments(gPipelines.plane.attachments);
    gPipelines.plane.attachments = sg_make_attachments(*attachmentsDesc);
}

create_plane_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := plane_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.buffers[0].stride = 4*3;


    pipeline.layout.attrs[ATTR_plane_position] = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.index_type = .UINT16;
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
            pixel_format = .DEPTH
    };

    color_state := sg_color_target_state.{
        pixel_format = .RGBA32F,
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        }
    };

    vertices: [4]Vector3 = .[
        .{-1.0, 0.0, -1.0},
        .{ 1.0, 0.0, -1.0},
        .{ 1.0, 0.0,  1.0},
        .{-1.0, 0.0,  1.0},
    ];

    indices: [6]u16 = .[
        0, 1, 2,
        0, 2, 3,
    ];


    pipeline.color_count = 1;
    pipeline.colors[0]   = color_state;

    gPipelines.plane.pipeline = sg_make_pipeline(*pipeline);

    ibuffer         := sg_buffer_desc.{ type = .INDEXBUFFER, data = .{ ptr = indices.data, size = 6 * 2 } };
    vbuffer         := sg_buffer_desc.{ data = .{ ptr = vertices.data, size = 4 * 3 * 4 } };

    gPipelines.plane.bind.index_buffer      = sg_make_buffer(*ibuffer);
    gPipelines.plane.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);
    create_plane_pipeline_reflection_images();



    gPipelines.plane.pass_action = .{
        colors[0] = .{ load_action = .CLEAR, clear_value = .{ 0.25, 0.25, 0.25, 1.0 } },
    };

    gPipelines.plane.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
    }));

    g_shadowmap_sampler = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        compare    = .LESS,
    }));
    
    gPipelines.plane.bind.samplers[1] = g_shadowmap_sampler;

    gPipelines.plane.bind.samplers[2] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .REPEAT,
        wrap_v = .REPEAT,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
    }));

    ground_img_desc := sg_image_desc.{
        width         = 1000,
        height        = 1000,
        pixel_format  = .RGBA8,
        render_target = false,
        sample_count  = 1,
        usage         = .DYNAMIC,
    };
}

create_arbtri_pipeline :: () {
    platconf := get_plat_conf();
    pipeline: sg_pipeline_desc;
    shader_desc := triangle_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);

    pipeline.layout.attrs[ATTR_triangle_position] = .{ format = .FLOAT3 };
    pipeline.layout.attrs[ATTR_triangle_color0]   = .{ format = .FLOAT4 };
    pipeline.layout.attrs[ATTR_triangle_uv]       = .{ format = .FLOAT2 };

    color_state := sg_color_target_state.{
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        }
    };

    pipeline.color_count = 1;
    pipeline.colors[0] = color_state;

    gPipelines.arbtri.pipeline = sg_make_pipeline(*pipeline);

    buffer := sg_buffer_desc.{ usage = .DYNAMIC, size = size_of(type_of(gArbtriMem)) };
    gPipelines.arbtri.bind.vertex_buffers[0] = sg_make_buffer(*buffer);
    gPipelines.arbtri.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));

}

create_postprocess_pipeline :: () {
    platconf := get_plat_conf();
    pipeline: sg_pipeline_desc;
    shader_desc := postprocess_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);

    pipeline.layout.attrs[ATTR_postprocess_position] = .{ format = .FLOAT2 };
    pipeline.layout.attrs[ATTR_postprocess_uv]       = .{ format = .FLOAT2 };
    pipeline.index_type = .UINT16;

    color_state := sg_color_target_state.{
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        }
    };

    pipeline.color_count = 1;
    pipeline.colors[0] = color_state;

    gPipelines.postprocess.pipeline = sg_make_pipeline(*pipeline);

    quad_vertices : [16]float = .[
        -1.0,  1.0, 0.0, flip_if_plat(1.0), // top-let
        -1.0, -1.0, 0.0, flip_if_plat(0.0), // bottom-let
         1.0, -1.0, 1.0, flip_if_plat(0.0), // bottom-right
         1.0,  1.0, 1.0, flip_if_plat(1.0), // top-right
    ];
    quad_indices  : [6]u16 = .[
        0, 1, 2, 0, 2, 3
    ];

    vbuffer := sg_buffer_desc.{ size = size_of(float) * 16, data = .{
        ptr = quad_vertices.data,
        size = 16 * 4
    }};
    ibuffer := sg_buffer_desc.{ size = size_of(u16) * 6, data = .{
        ptr = quad_indices.data,
        size = 6 * 2
    },
    type = .INDEXBUFFER,
    };

    gPipelines.postprocess.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);
    gPipelines.postprocess.bind.index_buffer = sg_make_buffer(*ibuffer);
    gPipelines.postprocess.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));

    gPipelines.postprocess.bind.samplers[1] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
    }));

}

// Takes in a texture, manipulates it and outputs it.
create_op_pipeline :: () {
    platconf := get_plat_conf();
    pipeline: sg_pipeline_desc;
    shader_desc := op_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);

    pipeline.layout.attrs[ATTR_op_position] = .{ format = .FLOAT2 };
    pipeline.layout.attrs[ATTR_op_uv]       = .{ format = .FLOAT2 };
    pipeline.index_type = .UINT16;

    color_state := sg_color_target_state.{
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        },
        pixel_format = .RGBA32F,
    };
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
            pixel_format = .DEPTH
    };

    pipeline.color_count = 1;
    pipeline.colors[0] = color_state;

    gPipelines.op.pipeline = sg_make_pipeline(*pipeline);

    quad_vertices : [16]float = .[
        -1.0,  1.0, 0.0, flip_if_plat(1.0), // top-let
        -1.0, -1.0, 0.0, flip_if_plat(0.0), // bottom-let
         1.0, -1.0, 1.0, flip_if_plat(0.0), // bottom-right
         1.0,  1.0, 1.0, flip_if_plat(1.0), // top-right
    ];
    quad_indices  : [6]u16 = .[
        0, 1, 2, 0, 2, 3
    ];

    vbuffer := sg_buffer_desc.{ size = size_of(float) * 16, data = .{
        ptr = quad_vertices.data,
        size = 16 * 4
    }};
    ibuffer := sg_buffer_desc.{ size = size_of(u16) * 6, data = .{
        ptr = quad_indices.data,
        size = 6 * 2
    },
    type = .INDEXBUFFER,
    };

    gPipelines.op.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);
    gPipelines.op.bind.index_buffer = sg_make_buffer(*ibuffer);
    gPipelines.op.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));

}

create_billboard_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := billboard_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.buffers[0].stride = 4*3;

    pipeline.layout.attrs[ATTR_billboard_position] = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.index_type = .UINT16;
    pipeline.depth = .{
        write_enabled = true,
        compare = .LESS_EQUAL,
        pixel_format = .DEPTH
    };

    color_state := sg_color_target_state.{
        pixel_format = .RGBA32F,
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        }
    };

    vertices: [4]Vector3 = .[
        .{ 0.0,  0.0, 0.0},
        .{ 1.0,  0.0, 0.0},
        .{ 1.0,  1.0, 0.0},
        .{ 0.0,  1.0, 0.0},
    ];

    indices: [6]u16 = .[
        0, 1, 2,
        0, 2, 3,
    ];


    pipeline.color_count = 1;
    pipeline.colors[0]   = color_state;

    gPipelines.billboard.pipeline = sg_make_pipeline(*pipeline);

    ibuffer         := sg_buffer_desc.{ type = .INDEXBUFFER, data = .{ ptr = indices.data, size = 6 * 2 } };
    vbuffer         := sg_buffer_desc.{ data = .{ ptr = vertices.data, size = 4 * 3 * 4 } };

    gPipelines.billboard.bind.index_buffer      = sg_make_buffer(*ibuffer);
    gPipelines.billboard.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);

    gPipelines.billboard.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));
}

create_gbuffer_billboard_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := gbuffer_billboard_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.buffers[0].stride = 4*3;

    pipeline.layout.attrs[ATTR_billboard_position] = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.index_type = .UINT16;
    pipeline.depth = .{
        write_enabled = true,
        compare = .LESS_EQUAL,
        pixel_format = .DEPTH
    };

    color_state_pos := sg_color_target_state.{
        pixel_format = .RGBA16F,
    };
    color_state_normal := sg_color_target_state.{
        pixel_format = .RGBA16F,
    };


    pipeline.color_count = 2;
    pipeline.colors[0]   = color_state_pos;
    pipeline.colors[1]   = color_state_normal;

    vertices: [4]Vector3 = .[
        .{ 0.0,  0.0, 0.0},
        .{ 1.0,  0.0, 0.0},
        .{ 1.0,  1.0, 0.0},
        .{ 0.0,  1.0, 0.0},
    ];

    indices: [6]u16 = .[
        0, 1, 2,
        0, 2, 3,
    ];

    pipeline.color_count = 2;
    pipeline.colors[0]   = color_state_pos;
    pipeline.colors[1]   = color_state_normal;

    gPipelines.gbuffer_billboard.pipeline = sg_make_pipeline(*pipeline);

    ibuffer         := sg_buffer_desc.{ type = .INDEXBUFFER, data = .{ ptr = indices.data, size = 6 * 2 } };
    vbuffer         := sg_buffer_desc.{ data = .{ ptr = vertices.data, size = 4 * 3 * 4 } };

    gPipelines.gbuffer_billboard.bind.index_buffer      = sg_make_buffer(*ibuffer);
    gPipelines.gbuffer_billboard.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);

    gPipelines.gbuffer_billboard.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));
}

// Takes in 2-3 textures, and mixes them.
create_mix_pipeline :: () {
    platconf := get_plat_conf();
    pipeline: sg_pipeline_desc;
    shader_desc := mix_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);

    pipeline.layout.attrs[ATTR_mix_position] = .{ format = .FLOAT2 };
    pipeline.layout.attrs[ATTR_mix_uv]       = .{ format = .FLOAT2 };
    pipeline.index_type = .UINT16;

    color_state := sg_color_target_state.{
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        },
        pixel_format = .RGBA32F,
    };
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
            pixel_format = .DEPTH
    };

    pipeline.color_count = 1;
    pipeline.colors[0] = color_state;

    gPipelines.mix.pipeline = sg_make_pipeline(*pipeline);

    quad_vertices : [16]float = .[
        -1.0,  1.0, 0.0, flip_if_plat(1.0), // top-let
        -1.0, -1.0, 0.0, flip_if_plat(0.0), // bottom-let
         1.0, -1.0, 1.0, flip_if_plat(0.0), // bottom-right
         1.0,  1.0, 1.0, flip_if_plat(1.0), // top-right
    ];
    quad_indices  : [6]u16 = .[
        0, 1, 2, 0, 2, 3
    ];

    vbuffer := sg_buffer_desc.{ size = size_of(float) * 16, data = .{
        ptr = quad_vertices.data,
        size = 16 * 4
    }};
    ibuffer := sg_buffer_desc.{ size = size_of(u16) * 6, data = .{
        ptr = quad_indices.data,
        size = 6 * 2
    },
    type = .INDEXBUFFER,
    };

    gPipelines.mix.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);
    gPipelines.mix.bind.index_buffer = sg_make_buffer(*ibuffer);
    gPipelines.mix.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));

}

create_ssao_images :: () {
    if g_ssaobuf.id != INVALID_ID then sg_destroy_image(g_ssaobuf);
    if g_ssaobuf_depth.id != INVALID_ID then sg_destroy_image(g_ssaobuf_depth);
    if g_postprocess_a.id != INVALID_ID then sg_destroy_image(g_postprocess_a);
    if g_postprocess_a_depth.id != INVALID_ID then sg_destroy_image(g_postprocess_a_depth);
    if g_postprocess_b.id != INVALID_ID then sg_destroy_image(g_postprocess_b);
    if g_postprocess_b_depth.id != INVALID_ID then sg_destroy_image(g_postprocess_b_depth);
    w,h := get_render_size();
    img_desc := sg_image_desc.{
        width = w/2,
        height = h/2,
        render_target = true,
        pixel_format = .RGBA32F
    };
    img_desc.sample_count = 1;
    g_ssaobuf = sg_make_image(*img_desc);
    img_desc.width *= 2; img_desc.height *= 2;
    g_postprocess_a = sg_make_image(*img_desc);
    g_postprocess_b = sg_make_image(*img_desc);
    img_desc = sg_image_desc.{
        width = w/2,
        height = h/2,
        pixel_format = .DEPTH,
        render_target = true,
    };
    img_desc.sample_count = 1;
    g_ssaobuf_depth = sg_make_image(*img_desc);
    img_desc.width *= 2; img_desc.height *= 2;
    g_postprocess_a_depth = sg_make_image(*img_desc);
    g_postprocess_b_depth = sg_make_image(*img_desc);
    
	attachmentsDesc := sg_attachments_desc.{
	    colors[0].image = g_ssaobuf,
        depth_stencil.image = g_ssaobuf_depth
	};
    sg_destroy_attachments(g_ssao_attachments);
    g_ssao_attachments = sg_make_attachments(*attachmentsDesc);
    
	attachmentsDescA := sg_attachments_desc.{
	    colors[0].image = g_postprocess_a,
        depth_stencil.image = g_postprocess_a_depth
	};
	attachmentsDescB := sg_attachments_desc.{
	    colors[0].image = g_postprocess_b,
        depth_stencil.image = g_postprocess_b_depth
	};
    sg_destroy_attachments(g_postprocess_attach_a);
    g_postprocess_attach_a = sg_make_attachments(*attachmentsDescA);
    sg_destroy_attachments(g_postprocess_attach_b);
    g_postprocess_attach_b = sg_make_attachments(*attachmentsDescB);
}

create_ssao_pipeline :: () {
    init_ssao();
    platconf := get_plat_conf();
    pipeline: sg_pipeline_desc;
    shader_desc := ssao_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);

    pipeline.layout.attrs[ATTR_ssao_position] = .{ format = .FLOAT2 };
    pipeline.layout.attrs[ATTR_ssao_uv]       = .{ format = .FLOAT2 };
    pipeline.index_type = .UINT16;

    color_state := sg_color_target_state.{
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        },
        pixel_format = .RGBA32F,
    };

    pipeline.color_count = 1;
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
            pixel_format = .DEPTH
    };
    pipeline.colors[0] = color_state;

    gPipelines.ssao.pipeline = sg_make_pipeline(*pipeline);

    quad_vertices : [16]float = .[
        -1.0,  1.0, 0.0, flip_if_plat(1.0), // top-let
        -1.0, -1.0, 0.0, flip_if_plat(0.0), // bottom-let
         1.0, -1.0, 1.0, flip_if_plat(0.0), // bottom-right
         1.0,  1.0, 1.0, flip_if_plat(1.0), // top-right
    ];
    quad_indices  : [6]u16 = .[
        0, 1, 2, 0, 2, 3
    ];

    vbuffer := sg_buffer_desc.{ size = size_of(float) * 16, data = .{
        ptr = quad_vertices.data,
        size = 16 * 4
    }};
    ibuffer := sg_buffer_desc.{ size = size_of(u16) * 6, data = .{
        ptr = quad_indices.data,
        size = 6 * 2
    },
    type = .INDEXBUFFER,
    };

    gPipelines.ssao.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);
    gPipelines.ssao.bind.index_buffer = sg_make_buffer(*ibuffer);
    gPipelines.ssao.bind.samplers[0] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .REPEAT,
        wrap_v = .REPEAT,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));


    imgdata : sg_image_data;
    imgdata.subimage[0][0] = .{g_ssao_noise.data, cast(u64) (16*4*4)};
    texdesc : sg_image_desc = .{
        render_target = false,
        width         = 4,
        height        = 4,  
        pixel_format  = sg_pixel_format.RGBA32F,
        sample_count  = 1,
        data          = imgdata
    };
    g_ssao_noise_buf = sg_make_image(*texdesc);
}

init_plane_textures :: () {
    gPipelines.plane.bind.images[2] = get_texture_from_pack("core", "utiltex/water_small.png");
}

init_brdf_lut :: () {
    g_brdf_lut = get_texture_from_pack("core", "utiltex/lut.png");
    if g_brdf_lut.id == INVALID_ID {
        // Create a 1x1 fallback so sokol doesn't drop draw calls
        pixels : [4]u8 = .[255, 255, 255, 255];
        imgdata : sg_image_data;
        imgdata.subimage[0][0] = .{ pixels.data, 4 };
        desc := sg_image_desc.{
            width = 1,
            height = 1,
            pixel_format = .RGBA8,
            data = imgdata,
        };
        g_brdf_lut = sg_make_image(*desc);
    }

    // 1x1 black image for RDM slots when no baked data is present.
    // The lookup texture returning all zeros makes atlas_rect.z == 0,
    // so the shader's fallback ambient path is taken.
    {
        pixels : [4]u8 = .[0, 0, 0, 0];
        imgdata : sg_image_data;
        imgdata.subimage[0][0] = .{ pixels.data, 4 };
        desc := sg_image_desc.{
            width = 1,
            height = 1,
            pixel_format = .RGBA8,
            data = imgdata,
        };
        g_rdm_fallback = sg_make_image(*desc);
    }
}

g_plane_gbuffer_vertex_buffer : sg_buffer;
g_plane_gbuffer_normal_buffer : sg_buffer;
g_plane_gbuffer_center_buffer : sg_buffer;
g_plane_gbuffer_instance_buffer : sg_buffer;

create_gbuffer_impostors :: () {
    plane_vertices: [6]Vector3 = .[
        .{-1.0, 0.0, -1.0},
        .{ 1.0, 0.0, -1.0},
        .{ 1.0, 0.0,  1.0},
        .{-1.0, 0.0, -1.0},
        .{ 1.0, 0.0,  1.0},
        .{-1.0, 0.0,  1.0},
    ];
    vbuffer := sg_buffer_desc.{ size = size_of(float) * 18, data = .{
        ptr = plane_vertices.data,
        size = 6 * 3 * 4
    }};
    g_plane_gbuffer_vertex_buffer = sg_make_buffer(*vbuffer);
    
    plane_normals: [6]Vector3 = .[
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
    ];
    nbuffer := sg_buffer_desc.{ size = size_of(float) * 18, data = .{
        ptr = plane_normals.data,
        size = 6 * 3 * 4
    }};
    g_plane_gbuffer_normal_buffer = sg_make_buffer(*nbuffer);
    
    plane_centers: [2]Vector3 = .[ // these are useless, just to fill the pipeline requirement.
        .{0.0, 1.0, 0.0},
        .{0.0, 1.0, 0.0},
    ];
    cbuffer := sg_buffer_desc.{ size = size_of(float) * 6, data = .{
        ptr = plane_centers.data,
        size = 3 * 2 * 4
    }};
    g_plane_gbuffer_center_buffer = sg_make_buffer(*cbuffer);

    instances: [1]Vector4 = .[.{0,0,0,0}];
    instance_buffer := sg_buffer_desc.{size = 4 * 4, data = .{
        ptr = instances.data,
        size = 4*4,
    }};
    g_plane_gbuffer_instance_buffer = sg_make_buffer(*instance_buffer);

}

create_particle_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := particle_shader_desc(sg_query_backend());
    shd := sg_make_shader(*shader_desc);
    pipeline.shader = shd;

    pipeline.layout.buffers[0].stride = 4 * 3;
    pipeline.layout.buffers[1].stride = 4 * 4;
    pipeline.layout.buffers[1].step_func = .PER_INSTANCE;
    pipeline.layout.buffers[2].stride = 4 * 4;
    pipeline.layout.buffers[2].step_func = .PER_INSTANCE;
    pipeline.layout.buffers[3].stride = 4 * 4;
    pipeline.layout.buffers[3].step_func = .PER_INSTANCE;

    pipeline.layout.attrs[ATTR_particle_position]      = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.layout.attrs[ATTR_particle_inst_pos_size]  = .{ format = .FLOAT4, buffer_index = 1 };
    pipeline.layout.attrs[ATTR_particle_inst_uv_rect]   = .{ format = .FLOAT4, buffer_index = 2 };
    pipeline.layout.attrs[ATTR_particle_inst_color]     = .{ format = .FLOAT4, buffer_index = 3 };

    pipeline.index_type = .UINT16;
    pipeline.depth = .{
        write_enabled = false,
        compare = .LESS_EQUAL,
        pixel_format = .DEPTH,
    };
    pipeline.color_count = 1;

    pipeline.colors[0] = .{
        pixel_format = .RGBA32F,
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE,
            src_factor_alpha = .ONE,
            dst_factor_alpha = .ONE,
        },
    };
    gPipelines.particle_additive.pipeline = sg_make_pipeline(*pipeline);

    pipeline.colors[0].blend = .{
        enabled = true,
        src_factor_rgb = .SRC_ALPHA,
        dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        src_factor_alpha = .ONE,
        dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
    };
    gPipelines.particle_alpha.pipeline = sg_make_pipeline(*pipeline);

    vertices: [4]Vector3 = .[
        .{ 0.0, 0.0, 0.0 },
        .{ 1.0, 0.0, 0.0 },
        .{ 1.0, 1.0, 0.0 },
        .{ 0.0, 1.0, 0.0 },
    ];

    indices: [6]u16 = .[
        0, 1, 2,
        0, 2, 3,
    ];

    idx_buf := sg_make_buffer(*(sg_buffer_desc.{ type = .INDEXBUFFER, data = .{ ptr = indices.data, size = 6 * 2 } }));
    vtx_buf := sg_make_buffer(*(sg_buffer_desc.{ data = .{ ptr = vertices.data, size = 4 * 3 * 4 } }));
    inst1   := sg_make_buffer(*(sg_buffer_desc.{ size = cast(u64)(MAX_PARTICLES * size_of(Vector4)), usage = .STREAM }));
    inst2   := sg_make_buffer(*(sg_buffer_desc.{ size = cast(u64)(MAX_PARTICLES * size_of(Vector4)), usage = .STREAM }));
    inst3   := sg_make_buffer(*(sg_buffer_desc.{ size = cast(u64)(MAX_PARTICLES * size_of(Vector4)), usage = .STREAM }));
    smp     := sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));

    setup_bind :: (bind: *sg_bindings, idx_buf: sg_buffer, vtx_buf: sg_buffer, inst1: sg_buffer, inst2: sg_buffer, inst3: sg_buffer, smp: sg_sampler) {
        bind.index_buffer      = idx_buf;
        bind.vertex_buffers[0] = vtx_buf;
        bind.vertex_buffers[1] = inst1;
        bind.vertex_buffers[2] = inst2;
        bind.vertex_buffers[3] = inst3;
        bind.samplers[SMP_particle_spritesmp] = smp;
    }
    setup_bind(*gPipelines.particle_additive.bind, idx_buf, vtx_buf, inst1, inst2, inst3, smp);
    setup_bind(*gPipelines.particle_alpha.bind, idx_buf, vtx_buf, inst1, inst2, inst3, smp);
}

create_debugline_pipeline :: () {
    buf_desc := sg_buffer_desc.{
        size  = DEBUG_LINE_MAX * 2 * 7 * size_of(float),
        usage = .DYNAMIC,
        label = "debug_line_verts",
    };
    gPipelines.debugline.bind.vertex_buffers[0] = sg_make_buffer(*buf_desc);

    pipeline : sg_pipeline_desc;
    shader_desc := debugline_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.primitive_type = .LINES;
    pipeline.layout.buffers[0].stride = 28;
    pipeline.layout.attrs[ATTR_debugline_a_pos] = .{ format = .FLOAT3, buffer_index = 0, offset = 0 };
    pipeline.layout.attrs[ATTR_debugline_a_col] = .{ format = .FLOAT4, buffer_index = 0, offset = 12 };
    pipeline.depth = .{
        write_enabled = false,
        compare       = .LESS_EQUAL,
        pixel_format  = .DEPTH,
    };
    color_state := sg_color_target_state.{
        pixel_format = .RGBA32F,
    };
    pipeline.color_count = 1;
    pipeline.colors[0]   = color_state;
    pipeline.label       = "debugline_pipeline";
    gPipelines.debugline.pipeline = sg_make_pipeline(*pipeline);
}
