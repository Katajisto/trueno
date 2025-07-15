@vs vs_trile

in vec4 position;
in vec4 normal;

layout(binding=0) uniform trile_vs_params {
    mat4 mvp;
};


out vec4 fnormal;

void main() {
    gl_Position = mvp * vec4(position.xyz, 1.0);
    fnormal = normal;
}
@end

@fs fs_trile

in vec4 fnormal;
out vec4 frag_color;

layout(binding = 0) uniform texture2D triletex;
layout(binding = 0) uniform sampler trilesmp;

void main() {
    //frag_color = vec4((fnormal.xyz + vec3(1.0, 1.0, 1.0)) * 0.5, 1.0);
    frag_color = texture(sampler2D(triletex, trilesmp), vec2(0.0));
}
@end

@program trile vs_trile fs_trile
