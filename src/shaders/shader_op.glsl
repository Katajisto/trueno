@vs vs_op
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_op
in vec2 texcoord;
out vec4 frag_color;

layout(binding = 0) uniform texture2D optex;
layout(binding = 0) uniform sampler opsmp;

void main() {
    vec2 texelSize = 1.0 / vec2(textureSize(sampler2D(optex, opsmp), 0));
    float result = 0.0;
    for (int x = -2; x < 2; ++x) 
    {
        for (int y = -2; y < 2; ++y) 
        {
            vec2 offset = vec2(float(x), float(y)) * texelSize;
            result += texture(sampler2D(optex, opsmp), texcoord + offset).r;
        }
    }
    frag_color = vec4(vec3(result / (4.0 * 4.0)), 1.0);
}
@end

@program op vs_op fs_op
