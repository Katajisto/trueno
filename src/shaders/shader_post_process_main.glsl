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

    
    vec3 color_hdr = sampled_color_hdr * exposure;

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

    float scanline = 1.0 - (sin(texcoord.y * textureSize(sampler2D(pptex, ppsmp), 0).y * scanlines_density) * 0.5 + 0.5) * scanlines_intensity;
    color_srgb *= scanline;

    float grain = (rand(texcoord) - 0.5) * film_grain_intensity;
    color_srgb += grain;
    
    frag_color = vec4(clamp(color_srgb, 0.0, 1.0), 1.0);
}
@end

@program postprocess vs_pp fs_pp
