#load "./shaders/jai/shader_triangle.jai";
#load "./shaders/jai/shader_trixel.jai";

Pipeline_Binding :: struct {
    pipeline : sg_pipeline;
    bind     : sg_bindings;
}

gPipelines : struct {

    // Arbitrary triangle rendering for rendering 2D things on the screen.
    // Used for UI rendering.
    arbtri : Pipeline_Binding;
    
    // Trixel rendering. Used for Trile editor rendering, in-game triles are rendered from
    // generated meshes.
    trixel : Pipeline_Binding;

}

create_pipelines :: () {
    create_arbtri_pipeline();
    create_trixel_pipeline();
}

TRIXEL_SIZE_HALF : float : 1.0/32.0;

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
    pipeline.layout.buffers[1].step_func = .PER_INSTANCE;
    
    pipeline.layout.attrs[ATTR_trixel_position] = .{ format = .FLOAT3, buffer_index = 0 };
    pipeline.layout.attrs[ATTR_trixel_inst]     = .{ format = .FLOAT4, buffer_index = 1 };
    pipeline.layout.attrs[ATTR_trixel_inst_col] = .{ format = .FLOAT4, buffer_index = 1 };
    pipeline.index_type = .UINT16;
    pipeline.depth = .{
            write_enabled = true,
            compare = .LESS_EQUAL,
    };

    color_state := sg_color_target_state.{
        pixel_format = .RGBA8,
        blend = .{
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
        }
    };

    verts : [24] Vector3;
	verts[0] = .{ -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF };
	verts[1] = .{ TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF  };
	verts[2] = .{ TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF   };
	verts[3] = .{ -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF  };

	verts[4] = .{ -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF  };
	verts[5] = .{ TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF   };
	verts[6] = .{ TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF    };
	verts[7] = .{ -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF   };

	verts[8] =  .{ -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF };
	verts[9] =  .{ -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF  };
	verts[10] = .{ -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF   };
	verts[11] = .{ -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF  };

	verts[12] = .{ TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF };
	verts[13] = .{ TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF  };
	verts[14] = .{ TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF   };
	verts[15] = .{ TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF  };

	verts[16] = .{ -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF };
	verts[17] = .{ -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF  };
	verts[18] = .{ TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF   };
	verts[19] = .{ TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF  };

	verts[20] = .{ -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF  };
	verts[21] = .{ -TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF   };
	verts[22] = .{ TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF    };
	verts[23] = .{ TRIXEL_SIZE_HALF, TRIXEL_SIZE_HALF, -TRIXEL_SIZE_HALF   };

	indices: [] u16 = .[
		0, 2, 1, 0, 3, 2,
		4, 6, 5, 4, 7, 6,
		8, 10, 9, 8, 11, 10,
		12, 14, 13, 12, 15, 14,
		16, 18, 17, 16, 19, 18,
		20, 22, 21, 20, 23, 22
	];
    
    pipeline.color_count = 1;
    pipeline.colors[0]   = color_state;

    gPipelines.trixel.pipeline = sg_make_pipeline(*pipeline);
    
    ibuffer         := sg_buffer_desc.{ type = .INDEXBUFFER, data = .{ ptr = indices.data, size = 36 * 2 } };
    vbuffer         := sg_buffer_desc.{ data = .{ ptr = verts.data, size = 24 * 3 * 4 } };
    instance_buffer := sg_buffer_desc.{ usage = .STREAM, size = 4096 * size_of(Position_Color)};

    gPipelines.trixel.bind.index_buffer      = sg_make_buffer(*ibuffer);
    gPipelines.trixel.bind.vertex_buffers[0] = sg_make_buffer(*vbuffer);
    gPipelines.trixel.bind.vertex_buffers[1] = sg_make_buffer(*instance_buffer);
}

create_arbtri_pipeline :: () {
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
