@vs vs_pp
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_pp
in vec2 texcoord;
out vec4 frag_color;

layout(binding = 0) uniform texture2D pptex;
layout(binding = 0) uniform sampler ppsmp;
layout(binding = 1) uniform texture2D lut;
layout(binding = 1) uniform sampler lut_linear;
layout(binding = 2) uniform texture2D bloom_tex;
layout(binding = 2) uniform sampler bloom_smp;

layout(binding=0) uniform post_process_config {
    float exposure;
    float contrast;
    float saturation;
    float gamma;
    float tonemap;
    float vignette_intensity;
    float vignette_radius;
    float scanlines_intensity;
    float scanlines_density;
    float chromatic_aberration_intensity;
    float film_grain_intensity;
    float barrel_distortion_intensity;
    int   lut_mode;
    float dither_intensity;
    float bloom_amount;
};

vec3 aces(vec3 x) {
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.43;
  const float d = 0.59;
  const float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float bayer8(vec2 pos) {
    ivec2 p = ivec2(pos) % 8;
    int index = p.x + p.y * 8;
    // Bayer 8x8 matrix, normalized to [0,1]
    const int bayer[64] = int[64](
         0, 32,  8, 40,  2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,
        12, 44,  4, 36, 14, 46,  6, 38,
        60, 28, 52, 20, 62, 30, 54, 22,
         3, 35, 11, 43,  1, 33,  9, 41,
        51, 19, 59, 27, 49, 17, 57, 25,
        15, 47,  7, 39, 13, 45,  5, 37,
        63, 31, 55, 23, 61, 29, 53, 21
    );
    return (float(bayer[index]) / 64.0) - 0.5;
}

void main() {
    vec2 distorted_texcoord = texcoord;
    float barrel_dist = length(texcoord - 0.5);
    distorted_texcoord -= 0.5;
    distorted_texcoord *= 1.0 + barrel_dist * barrel_distortion_intensity;
    distorted_texcoord += 0.5;

    if (barrel_distortion_intensity > 0.0) {
        if (distorted_texcoord.x < 0.0 || distorted_texcoord.x > 1.0 || distorted_texcoord.y < 0.0 || distorted_texcoord.y > 1.0) {
            frag_color = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
    }

    float r = texture(sampler2D(pptex, ppsmp), distorted_texcoord + vec2(chromatic_aberration_intensity, 0.0)).r;
    float g = texture(sampler2D(pptex, ppsmp), distorted_texcoord).g;
    float b = texture(sampler2D(pptex, ppsmp), distorted_texcoord - vec2(chromatic_aberration_intensity, 0.0)).b;
    vec3 sampled_color_hdr = vec4(r, g, b, 1.0).rgb;

    vec3 bloom_color = texture(sampler2D(bloom_tex, bloom_smp), distorted_texcoord).rgb;
    vec3 color_hdr = (sampled_color_hdr + bloom_color * bloom_amount) * exposure;

    vec3 color_ldr_linear;
    if(tonemap > 0.5) {
        color_ldr_linear = aces(color_hdr);
    } else {
        color_ldr_linear = color_hdr;
    }

    color_ldr_linear = ((color_ldr_linear - 0.5f) * max(contrast, 0)) + 0.5f;

    float lum = dot(color_ldr_linear, vec3(0.2125, 0.7154, 0.0721));
    vec3 brtColor = vec3(lum, lum, lum);
    color_ldr_linear = mix(brtColor, color_ldr_linear, saturation);

    color_ldr_linear = clamp(color_ldr_linear, 0.0, 1.0);

    if(dither_intensity > 0.0) {
        float dither = bayer8(gl_FragCoord.xy) * dither_intensity * (1.0 / 15.0);
        color_ldr_linear = clamp(color_ldr_linear + dither, 0.0, 1.0);
    }

    if(lut_mode != 0) {
        if(lut_mode == 2) {
            float u = floor(color_ldr_linear.b * 15.0) * (1.0/16.0);
            u = u + floor(color_ldr_linear.r * 15.0) * (1.0/256.0);
            float v = floor(color_ldr_linear.g * 15.0) * (1.0 / 16.0);
            vec3 left  = texture(sampler2D(lut, ppsmp), vec2(u, v)).rgb;
           color_ldr_linear = left;
        } else {
            float b_scaled = color_ldr_linear.b * 15.0;
            float b_floor = floor(b_scaled);
            float b_fract = b_scaled - b_floor; // fract(b_scaled)

            float v = (color_ldr_linear.g * 15.0 + 0.5) / 16.0;

            float u1 = (b_floor * 16.0 + color_ldr_linear.r * 15.0 + 0.5) / 256.0;
            vec3 sample1 = texture(sampler2D(lut, lut_linear), vec2(u1, v)).rgb;

            float b_ceil = min(b_floor + 1.0, 15.0); // Clamp to last slice
            float u2 = (b_ceil * 16.0 + color_ldr_linear.r * 15.0 + 0.5) / 256.0;
            vec3 sample2 = texture(sampler2D(lut, lut_linear), vec2(u2, v)).rgb;

            color_ldr_linear = mix(sample1, sample2, b_fract);
        }
    }

    vec3 color_srgb = pow(color_ldr_linear, vec3(1.0 / gamma));
    
    float vignette = 1.0 - smoothstep(0.0, vignette_radius, length(texcoord - vec2(0.5))) * vignette_intensity;
    color_srgb *= vignette;

    float scanline = 1.0 - (sin(gl_FragCoord.y * scanlines_density) * 0.5 + 0.5) * scanlines_intensity;
   
    color_srgb *= scanline;

    float grain = (rand(texcoord) - 0.5) * film_grain_intensity;
    color_srgb += grain;
    
    frag_color = vec4(clamp(color_srgb, 0.0, 1.0), 1.0);
}
@end

@program postprocess vs_pp fs_pp
