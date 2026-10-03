@vs vs_line
@include_block view
@include_block quad

layout(binding=1) uniform line_params {
    vec2 viewport;   // in pixels
};

in vec3 a;
in vec3 b;
in vec4 color;
in float width;     // in pixels

out vec4 v_color;

// A quad from a to b, widened across the line in screen space.
void main() {
    vec2 c = quad_corner(gl_VertexIndex);   // x: a to b, y: side
    vec4 clip_a = view_proj * vec4(a, 1.0);
    vec4 clip_b = view_proj * vec4(b, 1.0);
    vec2 screen_a = clip_a.xy / max(clip_a.w, 0.0001) * viewport;
    vec2 screen_b = clip_b.xy / max(clip_b.w, 0.0001) * viewport;
    vec2 dir = screen_b - screen_a;
    dir = dot(dir, dir) > 0.0001 ? normalize(dir) : vec2(1.0, 0.0);

    vec4 p = mix(clip_a, clip_b, c.x);
    p.xy += vec2(-dir.y, dir.x) * (c.y - 0.5) * width / viewport * p.w;
    gl_Position = p;
    v_color = color;
}
@end

@fs fs_line
@include_block transparent_out
in vec4 v_color;
void main() {
    write_transparent(v_color, 0.0);
}
@end

@program line vs_line fs_line
