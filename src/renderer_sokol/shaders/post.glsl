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

// Sunlight that came through glass, scattered toward the camera by the air between
// it and the first opaque surface. Half resolution.
@vs vs_shafts
@include_block view
@include_block fullscreen

out vec4 v_point;
out vec3 v_camera;
out vec3 v_sun;
out float v_time;

void main() {
    vec2 p = fullscreen_position(gl_VertexIndex);
    gl_Position = vec4(p, 0.0, 1.0);
    v_point  = inv_view_proj * vec4(p, 0.5, 1.0);
    v_camera = camera.xyz;
    v_sun    = sun_color.rgb;
    v_time   = camera.w;
}
@end

@fs fs_shafts
@include_block shadow
layout(binding=1) uniform shaft_params {
    float density;   // how much light scatters per unit, and how fast it fades
    float amount;
    float max_distance;
    float steps;
};
layout(binding=0) uniform texture2D shaft_scene;
layout(binding=0) uniform sampler shaft_scene_smp;
@image_sample_type shaft_scene unfilterable_float
@sampler_type shaft_scene_smp nonfiltering

in vec4 v_point;
in vec3 v_camera;
in vec3 v_sun;
in float v_time;
out vec4 frag_color;

const vec3  SHAFT_DRIFT   = vec3(0.4, 0.15, 0.3);    // how the air moves, units per second
const float SHAFT_SCALE   = 0.8;                      // size of the dusty patches, inverse units
const float SHAFT_SHIMMER = 1.0;                      // how much the dust thins and thickens the light
const float SHAFT_TINT    = 0.6;                      // how much of the glass colour the shafts keep

float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i),                  hash(i + vec3(1, 0, 0)), f.x),
                   mix(hash(i + vec3(0, 1, 0)),  hash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash(i + vec3(0, 0, 1)),  hash(i + vec3(1, 0, 1)), f.x),
                   mix(hash(i + vec3(0, 1, 1)),  hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Two layers drifting at different speeds, so the dust churns instead of sliding.
float dust(vec3 p) {
    vec3 q = p * SHAFT_SCALE;
    float n = value_noise(q + SHAFT_DRIFT * v_time * SHAFT_SCALE) * 0.65
            + value_noise(q * 2.3 - SHAFT_DRIFT.zxy * v_time * SHAFT_SCALE * 1.7) * 0.35;
    // Sharpened, so the patches read as clear gaps and thick wisps rather than a soft wobble.
    n = smoothstep(0.25, 0.75, n);
    return mix(1.0 - SHAFT_SHIMMER, 1.0 + SHAFT_SHIMMER, n);
}

void main() {
    vec3 dir = normalize(v_point.xyz / v_point.w - v_camera);
    float len = min(texelFetch(sampler2D(shaft_scene, shaft_scene_smp), ivec2(gl_FragCoord.xy) * 2, 0).r, max_distance);
    float step = len / steps;
    // Interleaved gradient noise spreads the step banding into a fine dither.
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

    vec3 light = vec3(0.0);
    for (float i = 0.0; i < steps; i += 1.0) {
        float t = (i + jitter) * step;
        // Snapped to the trixel grid, so the shafts are blocky like the patches they make.
        vec3 p = (floor((v_camera + dir * t) * 16.0) + 0.5) / 16.0;
        vec4 s = shadow_uv * vec4(p, 1.0);
        if (s.x < 0.0 || s.x > 1.0 || s.y < 0.0 || s.y > 1.0 || s.z > 1.0) continue;
        vec4 tint = texture(sampler2D(shadow_tint, shadow_tint_smp), s.xy);
        if (s.z < tint.a + 0.001) continue;
        float visible = texture(sampler2DShadow(shadow_map, shadow_smp), vec3(s.xy, s.z - 0.0005));
        vec3 color = mix(vec3(brightest(tint.rgb)), tint.rgb, SHAFT_TINT);
        light += visible * color * exp(-density * t) * dust(p);
    }
    frag_color = vec4(light * v_sun * density * step * amount, 1.0);
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
layout(binding=2) uniform texture2D shafts;
layout(binding=0) uniform sampler view_smp;
layout(binding=1) uniform sampler bloom_view_smp;
out vec4 frag_color;

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(textureSize(sampler2D(view_color, view_smp), 0));
    vec3 c = texture(sampler2D(view_color, view_smp), uv).rgb;
    c += texture(sampler2D(bloom, bloom_view_smp), uv).rgb * bloom_amount;
    // A small tent blur over the half resolution shafts hides their dither.
    vec2 st = 1.0 / vec2(textureSize(sampler2D(shafts, bloom_view_smp), 0));
    c += (texture(sampler2D(shafts, bloom_view_smp), uv).rgb * 2.0
        + texture(sampler2D(shafts, bloom_view_smp), uv + st * vec2( 1,  1)).rgb
        + texture(sampler2D(shafts, bloom_view_smp), uv + st * vec2(-1,  1)).rgb
        + texture(sampler2D(shafts, bloom_view_smp), uv + st * vec2( 1, -1)).rgb
        + texture(sampler2D(shafts, bloom_view_smp), uv + st * vec2(-1, -1)).rgb) / 6.0;
    c *= exp2(exposure);
    c = (c - 0.5) * contrast + 0.5;
    c = mix(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), c, saturation);
    frag_color = vec4(clamp(c, 0.0, 1.0), 1.0);
}
@end

@program bloom_glow vs_fullscreen fs_bloom_glow
@program bloom_down vs_fullscreen fs_bloom_down
@program bloom_up vs_fullscreen fs_bloom_up
@program shafts vs_shafts fs_shafts
@program post vs_fullscreen fs_post
