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
    float ssao_power;
};

in vec2 quad_uv;
out vec4 out_color;

void main() {
    vec3 frag_pos = texture(sampler2D(g_position, ssao_smp), quad_uv).xyz;
    vec3 normal = normalize(texture(sampler2D(g_normal, ssao_smp), quad_uv).rgb);
    vec2 noise_scale = vec2(1920.0/4.0, 1080.0/4.0); // @Incomplete: get screen size
    vec3 random_vec = normalize(texture(sampler2D(tex_noise, ssao_smp), quad_uv * noise_scale).xyz);

    vec3 tangent = normalize(random_vec - normal * dot(random_vec, normal));
    vec3 bitangent = cross(normal, tangent);
    mat3 tbn = mat3(tangent, bitangent, normal);

    float occlusion = 0.0;
    for(int i = 0; i < 64; i++) {
        vec3 sample_pos = tbn * samples[i].xyz;
        sample_pos = frag_pos + sample_pos * 0.5;

        vec4 offset = vec4(sample_pos, 1.0);
        offset = projection * offset;
        offset.xyz /= offset.w;
        offset.xyz = offset.xyz * 0.5 + 0.5;

        #if !SOKOL_GLSL
            offset.y = 1.0 - offset.y;
        #endif

        float bias = 0.01;
            
        vec3 psample = texture(sampler2D(g_position, ssao_smp), offset.xy).xyz;
        float occluded = 0.0;
        if(sample_pos.z + bias <= psample.z) { occluded = 1; } else { occluded = 0; }
        // float intensity = smoothstep(0.0, 1.0, 0.5 / abs(frag_pos.z - offset.z));
        // occluded *= intensity;
        occlusion += occluded;
        
    }
    occlusion = 1.0 - (occlusion / 64.0);
    out_color = vec4(vec3(pow(occlusion, ssao_power)), 1.0);
}
@end

@program ssao vs_ssao fs_ssao
