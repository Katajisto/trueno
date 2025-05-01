@vs vs
in vec4 position;
in vec4 color0;
in vec4 uv;

out vec4 color;
out vec4 texcoord;

void main() {
    gl_Position = position;
    color = color0;
    texcoord = uv;
}
@end

@fs fs
in vec4 color;
in vec4 texcoord;
out vec4 frag_color;

layout(binding = 0) uniform texture2D tex;
layout(binding = 0) uniform sampler smp;

bool is_near(float a, float b) {
    return abs(a-b) < 0.01;
}

void main() {
    if(is_near(texcoord.x, -4) && is_near(texcoord.y, -2)) {
        frag_color = color;
    } else {
        vec4 sampled = texture(sampler2D(tex, smp), texcoord.xy) * color;
        frag_color = sampled;
    }
}
@end

@program triangle vs fs
