@vs vs_bloom
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_bloom
in vec2 texcoord;
out vec4 frag_color;

layout(binding=0) uniform bloom_params {
    float bloom_treshold;
};

layout(binding = 0) uniform texture2D bloom_src;
layout(binding = 0) uniform sampler bloom_src_smp;

void main() {
    vec4 color = texture(sampler2D(bloom_src, bloom_src_smp), texcoord);
    float value = max(color.r, max(color.g, color.b));
    if(value < bloom_treshold) { color = vec4(0.0, 0.0, 0.0, 1.0); }
    frag_color = vec4(color.rgb, 1.0);
}
@end

@program bloom vs_bloom fs_bloom
