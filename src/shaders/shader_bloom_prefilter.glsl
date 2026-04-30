@vs vs_bloom_prefilter
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_bloom_prefilter
in vec2 texcoord;
out vec4 frag_color;

layout(binding=0) uniform bloom_prefilter_params {
    float src_texel_x;
    float src_texel_y;
    float threshold;
};

layout(binding = 0) uniform texture2D bloom_prefilter_src;
layout(binding = 0) uniform sampler bloom_prefilter_src_smp;

void main() {
    vec2 ts = vec2(src_texel_x, src_texel_y) * 0.5;
    vec3 a = texture(sampler2D(bloom_prefilter_src, bloom_prefilter_src_smp), texcoord + vec2(-ts.x, -ts.y)).rgb;
    vec3 b = texture(sampler2D(bloom_prefilter_src, bloom_prefilter_src_smp), texcoord + vec2( ts.x, -ts.y)).rgb;
    vec3 c = texture(sampler2D(bloom_prefilter_src, bloom_prefilter_src_smp), texcoord + vec2(-ts.x,  ts.y)).rgb;
    vec3 d = texture(sampler2D(bloom_prefilter_src, bloom_prefilter_src_smp), texcoord + vec2( ts.x,  ts.y)).rgb;
    vec3 color = (a + b + c + d) * 0.25;
    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
    if (lum < threshold) color = vec3(0.0);
    frag_color = vec4(color, 1.0);
}
@end

@program bloom_prefilter vs_bloom_prefilter fs_bloom_prefilter
