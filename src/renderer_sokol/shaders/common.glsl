@block view
layout(binding=0) uniform view_params {
    mat4 view_proj;
    mat4 inv_view_proj;
    vec4 camera;   // xyz = position, w = time
    vec4 clip;     // plane; geometry on its negative side is dropped
    vec4 sun_direction;
    vec4 sun_color;
    vec4 shade_color;
};
@end

@block quad
vec2 quad_corner(int vertex_index) {
    const vec2 corners[6] = vec2[6](vec2(0, 0), vec2(1, 0), vec2(1, 1), vec2(0, 0), vec2(1, 1), vec2(0, 1));
    return corners[vertex_index];
}
@end

// Opaque passes also write how much each pixel glows, and its distance from the
// camera for water depth.
@block scene_out
layout(location=0) out vec4 frag_color;
layout(location=1) out vec4 frag_glow;
layout(location=2) out vec4 frag_scene;
void write_scene(vec3 to_camera, float glow) {
    frag_glow  = vec4(glow);
    frag_scene = vec4(length(to_camera));
}
@end

// Transparent passes blend glow with the same alpha as colour.
@block transparent_out
layout(location=0) out vec4 frag_color;
layout(location=1) out vec4 frag_glow;
void write_transparent(vec4 color, float glow) {
    frag_color = color;
    frag_glow  = vec4(glow, 0.0, 0.0, color.a);
}
@end

@block emissive
const float EMISSIVE_GLOW = 8.0;   // bloom strength of something fully emissive
@end

@block shadow
layout(binding=3) uniform shadow_params {
    mat4 shadow_uv;   // world to shadow map uv and depth
};
layout(binding=7) uniform texture2D shadow_map;
layout(binding=7) uniform sampler shadow_smp;
layout(binding=8) uniform texture2D shadow_tint;   // what colour glass gave the sunlight
layout(binding=8) uniform sampler shadow_tint_smp;
@image_sample_type shadow_map depth
@sampler_type shadow_smp comparison

float brightest(vec3 c) { return max(c.r, max(c.g, c.b)); }

// White in sunlight, black in shadow, coloured behind glass. Looked up at the
// centre of the trixel face, so shadow edges follow the trixel grid.
vec3 sun_shadow(vec3 world, vec3 normal) {
    vec3 half_trixel = normal * (0.5 / 16.0);
    vec3 face = (floor((world - half_trixel) * 16.0) + 0.5) / 16.0 + half_trixel;
    vec4 p = shadow_uv * vec4(face + normal * 0.02, 1.0);
    if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) return vec3(1.0);
    float visible = texture(sampler2DShadow(shadow_map, shadow_smp), vec3(p.xy, p.z - 0.0005));
    return visible * texture(sampler2D(shadow_tint, shadow_tint_smp), p.xy).rgb;
}
@end

@block fullscreen
// Clip-space corner of a triangle that covers the screen, for vertices 0..2.
vec2 fullscreen_position(int vertex_index) {
    return vec2((vertex_index << 1) & 2, vertex_index & 2) * 2.0 - 1.0;
}
@end
