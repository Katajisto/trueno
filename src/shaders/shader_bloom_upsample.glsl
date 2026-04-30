@vs vs_bloom_upsample
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_bloom_upsample
in vec2 texcoord;
out vec4 frag_color;

layout(binding=0) uniform bloom_upsample_params {
    float src_texel_x;
    float src_texel_y;
};

layout(binding = 0) uniform texture2D bloom_upsample_small;
layout(binding = 0) uniform sampler bloom_upsample_small_smp;
layout(binding = 1) uniform texture2D bloom_upsample_large;
layout(binding = 1) uniform sampler bloom_upsample_large_smp;

void main() {
    vec2 ts = vec2(src_texel_x, src_texel_y) * 0.5;
    vec3 tent =
        texture(sampler2D(bloom_upsample_small, bloom_upsample_small_smp), texcoord + vec2(-ts.x, -ts.y)).rgb +
        texture(sampler2D(bloom_upsample_small, bloom_upsample_small_smp), texcoord + vec2( ts.x, -ts.y)).rgb +
        texture(sampler2D(bloom_upsample_small, bloom_upsample_small_smp), texcoord + vec2(-ts.x,  ts.y)).rgb +
        texture(sampler2D(bloom_upsample_small, bloom_upsample_small_smp), texcoord + vec2( ts.x,  ts.y)).rgb;
    vec3 large = texture(sampler2D(bloom_upsample_large, bloom_upsample_large_smp), texcoord).rgb;
    frag_color = vec4(tent * 0.25 + large, 1.0);
}
@end

@program bloom_upsample vs_bloom_upsample fs_bloom_upsample
