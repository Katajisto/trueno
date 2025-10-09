SHADOWMAP_SIZE :: 2000;

Pipeline_Binding :: struct {
    pipeline    : sg_pipeline;
    bind        : sg_bindings;
    attachments : sg_attachments;
    pass_action : sg_pass_action;
}

g_specular_lut  : sg_image;

g_shadowmap             : sg_image;
g_shadowmap_img         : sg_image;
g_shadowmap_attachments : sg_attachments;
g_shadowmap_sampler     : sg_sampler;

g_rendertex             : sg_image;
g_rendertex_depth       : sg_image;
g_rendertex_attachments : sg_attachments;

gPipelines : struct {

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

    // Renders the ground plane.
    plane  : Pipeline_Binding;

    postprocess : Pipeline_Binding;
}

create_final_image :: () {
    // @ToDo: Some smarter logic for this.
    w,h := get_render_size();

    if g_rendertex.id != INVALID_ID then sg_destroy_image(g_rendertex);
    if g_rendertex_depth.id != INVALID_ID then sg_destroy_image(g_rendertex);

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
    create_arbtri_pipeline();
    create_trixel_pipeline();
    create_trile_pipeline();
    create_sky_pipeline();
    create_plane_pipeline();
    create_postprocess_pipeline();
    
    create_shadowmap_image();
    create_final_image();
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

// @ToDo: This needs to be redone when the window is resized;
create_plane_pipeline_reflection_images :: () {
    binding := *gPipelines.plane.bind;
    if binding.images[4].id != INVALID_ID then sg_destroy_image(binding.images[4]);
    if binding.images[5].id != INVALID_ID then sg_destroy_image(binding.images[5]);
    if binding.images[0].id != INVALID_ID then sg_destroy_image(binding.images[0]);

    w, h := get_render_size();
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
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));

    g_shadowmap_sampler = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
        compare    = .LESS,
    }));
    
    gPipelines.plane.bind.samplers[1] = sg_make_sampler(*(sg_sampler_desc.{
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    }));


    ground_img_desc := sg_image_desc.{
        width         = 1000,
        height        = 1000,
        pixel_format  = .RGBA8,
        render_target = false,
        sample_count  = 1,
        usage         = .DYNAMIC,
    };

    gPipelines.plane.bind.images[1] = sg_make_image(*ground_img_desc);
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
        pixel_format = .RGBA8,
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
        pixel_format = .RGBA8,
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
        -1.0,  1.0, 0.0, 1.0, // top-let
        -1.0, -1.0, 0.0, 0.0, // bottom-let
         1.0, -1.0, 1.0, 0.0, // bottom-right
         1.0,  1.0, 1.0, 1.0, // top-right
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

}
