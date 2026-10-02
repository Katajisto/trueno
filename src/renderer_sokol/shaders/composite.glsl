@vs vs_composite
layout(binding=0) uniform composite_vs_params {
    float flip_y;
};

out vec2 v_uv;

void main() {
    vec2 p = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
    v_uv = vec2(p.x, mix(p.y, 1.0 - p.y, flip_y));
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
@end

@fs fs_composite
in vec2 v_uv;
out vec4 frag_color;

layout(binding=0) uniform texture2D view_color;
layout(binding=0) uniform sampler composite_smp;

void main() {
    frag_color = texture(sampler2D(view_color, composite_smp), v_uv);
}
@end

@program composite vs_composite fs_composite
