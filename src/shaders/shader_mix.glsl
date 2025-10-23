@vs vs_mix
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_mix
in vec2 texcoord;
out vec4 frag_color;

layout(binding=1) uniform mix_fs_params {
    int op;
    float dof_min;
    float dof_max;
    float dof_point;
    /*
        List of mixs:
        0. blur for ssao
        1. dilate.
        2. normal blur
    */
};

layout(binding = 0) uniform texture2D mixtex_a;
layout(binding = 1) uniform texture2D mixtex_b;
layout(binding = 2) uniform texture2D mixtex_c;
layout(binding = 0) uniform sampler mixsmp;

void main() {
    if(op == 0) {
        vec2 texelSize = 1.0 / vec2(textureSize(sampler2D(mixtex_a, mixsmp), 0));
        vec3 in_focus  = texture(sampler2D(mixtex_b, mixsmp), texcoord).rgb;
        vec3 out_focus = texture(sampler2D(mixtex_a, mixsmp), texcoord).rgb;
        vec4 position  = texture(sampler2D(mixtex_c, mixsmp), texcoord);
        float blur = smoothstep(dof_min, dof_max, abs(position.z + dof_point));
        frag_color = vec4(mix(in_focus, out_focus, blur), 1.0);
    } else {
        frag_color = vec4(1.0);
    }
}
@end

@program mix vs_mix fs_mix
