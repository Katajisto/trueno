@vs vs_trixel

in vec4 position;
in vec4 inst;
in vec4 inst_col;

layout(binding=0) uniform vs_params {
    mat4 mvp;
};


out vec4 color;

void main() {
    vec3 instancepos = inst.xyz;
    gl_Position = mvp * (vec4(position.xyz + instancepos, 1.0));
    color = inst_col;
}
@end

@fs fs_trixel
in vec4 color;
out vec4 frag_color;


void main() {
    frag_color = color;
}
@end

@program trixel vs_trixel fs_trixel
