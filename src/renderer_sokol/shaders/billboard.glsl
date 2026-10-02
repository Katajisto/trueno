@vs vs_billboard
@include_block view
@include_block quad

in vec3 center;   // bottom middle
in vec2 size;
in vec4 uv_rect;
in vec3 face;

out float v_clip;
out vec2 v_uv;

void main() {
    vec2 c = quad_corner(gl_VertexIndex);
    vec3 look = face;
    if (face.x < -10.0) look = vec3(center.x - camera.x, 0.0, center.z - camera.z);
    if (dot(look.xz, look.xz) < 0.0001) look = vec3(0.0, 0.0, 1.0);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), look));

    vec3 world = center + right * ((c.x - 0.5) * size.x) + vec3(0.0, c.y * size.y, 0.0);
    gl_Position = view_proj * vec4(world, 1.0);
    v_clip = dot(vec4(world, 1.0), clip);
    v_uv   = vec2(uv_rect.x + c.x * uv_rect.z, uv_rect.y + (1.0 - c.y) * uv_rect.w);
}
@end

@fs fs_billboard
in float v_clip;
in vec2 v_uv;
out vec4 frag_color;

layout(binding=0) uniform texture2D sprite;
layout(binding=0) uniform sampler sprite_smp;

void main() {
    if (v_clip < 0.0) discard;
    vec4 sampled = texture(sampler2D(sprite, sprite_smp), v_uv);
    if (sampled.a < 0.01) discard;
    frag_color = vec4(sampled.rgb, 1.0);
}
@end

@program billboard vs_billboard fs_billboard
