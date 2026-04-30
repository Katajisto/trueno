@vs vs_bloom_downsample
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_bloom_downsample
in vec2 texcoord;
out vec4 frag_color;

layout(binding=0) uniform bloom_downsample_params {
    float src_texel_x;
    float src_texel_y;
};

layout(binding = 0) uniform texture2D bloom_downsample_src;
layout(binding = 0) uniform sampler bloom_downsample_src_smp;

void main() {
    vec2 ts = vec2(src_texel_x, src_texel_y) * 0.5;
    vec3 a = texture(sampler2D(bloom_downsample_src, bloom_downsample_src_smp), texcoord + vec2(-ts.x, -ts.y)).rgb;
    vec3 b = texture(sampler2D(bloom_downsample_src, bloom_downsample_src_smp), texcoord + vec2( ts.x, -ts.y)).rgb;
    vec3 c = texture(sampler2D(bloom_downsample_src, bloom_downsample_src_smp), texcoord + vec2(-ts.x,  ts.y)).rgb;
    vec3 d = texture(sampler2D(bloom_downsample_src, bloom_downsample_src_smp), texcoord + vec2( ts.x,  ts.y)).rgb;
    frag_color = vec4((a + b + c + d) * 0.25, 1.0);
}
@end

@program bloom_downsample vs_bloom_downsample fs_bloom_downsample
