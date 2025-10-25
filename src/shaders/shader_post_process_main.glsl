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

    vec4 sampled = vec4(0.0);
    float r = texture(sampler2D(pptex, ppsmp), distorted_texcoord + vec2(chromatic_aberration_intensity, 0.0)).r;
    float g = texture(sampler2D(pptex, ppsmp), distorted_texcoord).g;
    float b = texture(sampler2D(pptex, ppsmp), distorted_texcoord - vec2(chromatic_aberration_intensity, 0.0)).b;
    sampled = vec4(r, g, b, 1.0);

    vec3 tonemapped = aces(sampled.xyz);
    if(tonemap > 0.5) {
        tonemapped = aces(sampled.xyz);
    } else {
        tonemapped = sampled.xyz;
    }
    // tonemapped *= pow(2.0, exposure);
    vec3 gammaCorrected = pow(tonemapped, vec3(1.0/gamma));
    gammaCorrected.rgb = ((gammaCorrected.rgb - 0.5f) * max(contrast, 0)) + 0.5f;
    gammaCorrected.rgb += exposure;

    float lum = (0.2125 * gammaCorrected.r) + (0.7154 * gammaCorrected.g) + (0.0721 * gammaCorrected.b);
    vec3 brtColor = vec3(lum, lum, lum);
    gammaCorrected.rgb = mix(brtColor, gammaCorrected.rgb, saturation);

    float vignette = 1.0 - smoothstep(0.0, vignette_radius, length(texcoord - vec2(0.5))) * vignette_intensity;
    gammaCorrected.rgb *= vignette;

    float scanline = 1.0 - (sin(texcoord.y * textureSize(sampler2D(pptex, ppsmp), 0).y * scanlines_density) * 0.5 + 0.5) * scanlines_intensity;
    gammaCorrected.rgb *= scanline;

    float grain = (rand(texcoord) - 0.5) * film_grain_intensity;
    gammaCorrected.rgb += grain;
    
    frag_color = vec4(gammaCorrected, 1.0);
}
@end

@program postprocess vs_pp fs_pp
