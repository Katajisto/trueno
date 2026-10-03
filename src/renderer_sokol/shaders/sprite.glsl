@vs vs_sprite
@include_block view
@include_block quad

layout(binding=1) uniform sprite_params {
    float lit;
};

in vec3 center;   // bottom middle
in vec2 size;
in vec4 uv_rect;
in vec3 face;
in vec4 color;
in float glow;

out float v_clip;
out vec3 v_to_camera;
out vec2 v_uv;
out vec4 v_color;
out vec3 v_sun;
out vec3 v_shade;
out vec3 v_anchor;
out float v_glow;

void main() {
    vec2 c = quad_corner(gl_VertexIndex);
    vec3 look = face;
    if (face.x < -10.0) look = vec3(center.x - camera.x, 0.0, center.z - camera.z);
    if (dot(look.xz, look.xz) < 0.0001) look = vec3(0.0, 0.0, 1.0);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), look));

    vec3 world = center + right * ((c.x - 0.5) * size.x) + vec3(0.0, c.y * size.y, 0.0);
    gl_Position = view_proj * vec4(world, 1.0);
    v_clip = dot(vec4(world, 1.0), clip);
    v_to_camera = camera.xyz - world;
    v_uv    = vec2(uv_rect.x + c.x * uv_rect.z, uv_rect.y + (1.0 - c.y) * uv_rect.w);
    v_color = color;
    v_glow  = glow;
    v_sun   = lit > 0.5 ? sun_color.rgb : vec3(1.0);
    v_shade = lit > 0.5 ? shade_color.rgb : vec3(1.0);
    // The whole sprite takes the shadow found inside its body, nudged toward the
    // sun so it doesn't find its own shadow.
    v_anchor = center + vec3(0.0, size.y * 0.5, 0.0) + sun_direction.xyz * 0.3;
}
@end

@block sprite_fs
in float v_clip;
in vec3 v_to_camera;
in vec2 v_uv;
in vec4 v_color;
in vec3 v_sun;
in vec3 v_shade;
in vec3 v_anchor;
in float v_glow;

layout(binding=0) uniform texture2D sprite;
layout(binding=0) uniform sampler sprite_smp;

vec4 sprite_color() {
    if (v_clip < 0.0) discard;
    vec4 sampled = texture(sampler2D(sprite, sprite_smp), v_uv);
    if (sampled.a < 0.01) discard;
    return sampled * v_color;
}
@end

@fs fs_sprite
@include_block scene_out
@include_block shadow
@include_block sprite_fs
void main() {
    vec3 light = mix(v_shade, v_sun, sun_shadow(v_anchor, vec3(0.0, 1.0, 0.0)));
    frag_color = sprite_color() * vec4(light, 1.0);
    write_scene(v_to_camera, 0.0);
}
@end

@fs fs_particle
@include_block sprite_fs
@include_block transparent_out
@include_block emissive
void main() {
    write_transparent(sprite_color(), v_glow * EMISSIVE_GLOW);
}
@end

@fs fs_sprite_shadow
@include_block sprite_fs
void main() {
    sprite_color();
}
@end

@program sprite vs_sprite fs_sprite
@program particle vs_sprite fs_particle
@program sprite_shadow vs_sprite fs_sprite_shadow
