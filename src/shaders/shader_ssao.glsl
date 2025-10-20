@vs vs_ssao
in vec2 position;
in vec2 uv;

out vec2 quad_uv;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    quad_uv = uv;
}
@end

@fs fs_ssao

layout(binding=0) uniform texture2D g_position;
layout(binding=1) uniform texture2D g_normal;
layout(binding=2) uniform texture2D tex_noise;

layout(binding=0) uniform sampler ssao_smp;

layout(binding=1) uniform ssao_fs_params {
    mat4 projection;
    vec4 samples[64];
};

in vec2 quad_uv;
out vec4 out_color;

void main() {
    vec3 frag_pos = texture(sampler2D(g_position, ssao_smp), quad_uv).xyz;
    vec3 normal = normalize(texture(sampler2D(g_normal, ssao_smp), quad_uv).rgb);
    vec2 noise_scale = vec2(1280.0/4.0, 720.0/4.0); // @Incomplete: get screen size
    vec3 random_vec = normalize(texture(sampler2D(tex_noise, ssao_smp), quad_uv * noise_scale).xyz);

    vec3 tangent = normalize(random_vec - normal * dot(random_vec, normal));
    vec3 bitangent = cross(normal, tangent);
    mat3 tbn = mat3(tangent, bitangent, normal);

    float occlusion = 0.0;
    for (int i = 0; i < 64; ++i) {
        vec3 sample_pos = tbn * samples[i].xyz;
        sample_pos = frag_pos + sample_pos;

        vec4 offset = vec4(sample_pos, 1.0);
        offset = projection * offset;
        offset.xy /= offset.w;
        offset.xy = offset.xy * 0.5 + 0.5;

        float sample_depth = texture(sampler2D(g_position, ssao_smp), offset.xy).z;
        float range_check = smoothstep(0.0, 1.0, 1.0 - (frag_pos.z - sample_depth));
        occlusion += (sample_depth >= sample_pos.z ? 1.0 : 0.0) * range_check;
    }

    occlusion = 1.0 - (occlusion / 64.0);
    out_color = vec4(occlusion, occlusion, occlusion, 1.0);
}
@end

@program ssao vs_ssao fs_ssao
