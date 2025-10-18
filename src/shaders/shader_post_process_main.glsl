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
};

vec3 aces(vec3 x) {
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.43;
  const float d = 0.59;
  const float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec4 sampled = texture(sampler2D(pptex, ppsmp), texcoord.xy);
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
    
    frag_color = vec4(gammaCorrected, 1.0);
}
@end

@program postprocess vs_pp fs_pp
