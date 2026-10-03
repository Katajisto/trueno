// Texture coordinates come from the pixel position, which lines up with
// render-target textures the same way on every backend.

@vs vs_fullscreen
@include_block fullscreen
void main() {
    gl_Position = vec4(fullscreen_position(gl_VertexIndex), 0.0, 1.0);
}
@end

// The first level: colour times glow, averaged over each 2x2 block of view pixels.
@fs fs_bloom_glow
layout(binding=0) uniform texture2D bloom_source;
layout(binding=1) uniform texture2D bloom_glow;
layout(binding=0) uniform sampler bloom_smp;
out vec4 frag_color;

vec3 glowing(ivec2 p) {
    return texelFetch(sampler2D(bloom_source, bloom_smp), p, 0).rgb * texelFetch(sampler2D(bloom_glow, bloom_smp), p, 0).r;
}

void main() {
    ivec2 p = ivec2(gl_FragCoord.xy) * 2;
    vec3 c = (glowing(p) + glowing(p + ivec2(1, 0)) + glowing(p + ivec2(0, 1)) + glowing(p + ivec2(1, 1))) * 0.25;
    frag_color = vec4(c, 1.0);
}
@end

@fs fs_bloom_down
layout(binding=0) uniform texture2D bloom_source;
layout(binding=0) uniform sampler bloom_smp;
out vec4 frag_color;

vec3 tap(vec2 uv) { return texture(sampler2D(bloom_source, bloom_smp), uv).rgb; }

void main() {
    vec2 texel = 1.0 / vec2(textureSize(sampler2D(bloom_source, bloom_smp), 0));
    vec2 uv = gl_FragCoord.xy * 2.0 * texel;
    vec3 c = (tap(uv + texel * vec2(-1, -1)) + tap(uv + texel * vec2(1, -1)) +
              tap(uv + texel * vec2(-1,  1)) + tap(uv + texel * vec2(1,  1))) * 0.25;
    frag_color = vec4(c, 1.0);
}
@end

@fs fs_bloom_up
layout(binding=0) uniform texture2D bloom_source;
layout(binding=0) uniform sampler bloom_smp;
out vec4 frag_color;

vec3 tap(vec2 uv) { return texture(sampler2D(bloom_source, bloom_smp), uv).rgb; }

// A 3x3 tent over the smaller level, added onto the larger one.
void main() {
    vec2 texel = 1.0 / vec2(textureSize(sampler2D(bloom_source, bloom_smp), 0));
    vec2 uv = gl_FragCoord.xy * 0.5 * texel;
    vec3 c = tap(uv) * 4.0
           + (tap(uv + texel * vec2(-1, 0)) + tap(uv + texel * vec2(1, 0)) + tap(uv + texel * vec2(0, -1)) + tap(uv + texel * vec2(0, 1))) * 2.0
           + (tap(uv + texel * vec2(-1, -1)) + tap(uv + texel * vec2(1, -1)) + tap(uv + texel * vec2(-1, 1)) + tap(uv + texel * vec2(1, 1)));
    frag_color = vec4(c / 16.0, 1.0);
}
@end

@fs fs_post
layout(binding=0) uniform post_params {
    float exposure;     // in stops
    float contrast;
    float saturation;
    float bloom_amount;
};
layout(binding=0) uniform texture2D view_color;
layout(binding=1) uniform texture2D bloom;
layout(binding=0) uniform sampler view_smp;
layout(binding=1) uniform sampler bloom_view_smp;
out vec4 frag_color;

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(textureSize(sampler2D(view_color, view_smp), 0));
    vec3 c = texture(sampler2D(view_color, view_smp), uv).rgb;
    c += texture(sampler2D(bloom, bloom_view_smp), uv).rgb * bloom_amount;
    c *= exp2(exposure);
    c = (c - 0.5) * contrast + 0.5;
    c = mix(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), c, saturation);
    frag_color = vec4(clamp(c, 0.0, 1.0), 1.0);
}
@end

@program bloom_glow vs_fullscreen fs_bloom_glow
@program bloom_down vs_fullscreen fs_bloom_down
@program bloom_up vs_fullscreen fs_bloom_up
@program post vs_fullscreen fs_post
