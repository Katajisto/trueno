Pipeline_Binding :: struct {
    pipeline: sg_pipeline;
    bind: sg_bindings;
}

gPipelines : struct {
    arbtri: Pipeline_Binding;
}

create_pipelines :: () {
    create_arbtri_pipeline();
}

gArbtriMem : [1000*3*9]float;

create_arbtri_pipeline :: () {
    pipeline: sg_pipeline_desc;
    shader_desc := triangle_shader_desc(sg_query_backend());
    pipeline.shader = sg_make_shader(*shader_desc);
    pipeline.layout.attrs[ATTR_triangle_position] = .{ format = .FLOAT3 };
    pipeline.layout.attrs[ATTR_triangle_color0]    = .{ format = .FLOAT4 };
    pipeline.layout.attrs[ATTR_triangle_uv]    = .{ format = .FLOAT2 };
    gPipelines.arbtri.pipeline = sg_make_pipeline(*pipeline);
    
    buffer := sg_buffer_desc.{ usage = .DYNAMIC, size = size_of(type_of(gArbtriMem)) };
    gPipelines.arbtri.bind.vertex_buffers[0] = sg_make_buffer(*buffer);
}
