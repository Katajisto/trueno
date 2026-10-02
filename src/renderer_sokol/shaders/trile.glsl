@vs vs_trile
@include_block view

layout(binding=1) uniform trile_params {
    vec4 orientations[72];
};

in vec3 position;
in float swatch;
in float ao;
in vec4 instance;   // xyz = position, w = orientation
in float tint;

out float v_clip;
out float v_swatch;
out float v_ao;
out float v_tint;

void main() {
    int ori = int(instance.w + 0.5) * 3;
    vec3 p = position - 0.5;
    vec3 world = vec3(dot(orientations[ori].xyz, p),
                      dot(orientations[ori + 1].xyz, p),
                      dot(orientations[ori + 2].xyz, p)) + 0.5 + instance.xyz;
    gl_Position = view_proj * vec4(world, 1.0);
    v_clip   = dot(vec4(world, 1.0), clip);
    v_swatch = swatch;
    v_ao     = ao;
    v_tint   = tint;
}
@end

@fs fs_trile
in float v_clip;
in float v_swatch;
in float v_ao;
in float v_tint;
out vec4 frag_color;

layout(binding=0) uniform texture2D palette;
layout(binding=0) uniform sampler palette_smp;

void main() {
    if (v_clip < 0.0) discard;
    vec3 albedo = texelFetch(sampler2D(palette, palette_smp), ivec2(int(v_swatch + 0.5), 0), 0).rgb;
    albedo *= mix(0.4, 1.0, v_ao);
    if (v_tint > 1.5)      albedo = mix(albedo, vec3(1.0, 0.2, 0.2), 0.5);
    else if (v_tint > 0.5) albedo = mix(albedo, vec3(0.2, 1.0, 0.2), 0.5);
    frag_color = vec4(albedo, 1.0);
}
@end

@program trile vs_trile fs_trile
