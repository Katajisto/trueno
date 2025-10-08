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

void main() {
    vec4 sampled = texture(sampler2D(pptex, ppsmp), texcoord.xy);
    frag_color = sampled;
}
@end

@program postprocess vs_pp fs_pp
