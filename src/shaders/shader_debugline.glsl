@vs vs_debugline

in vec3 a_pos;
in vec4 a_col;

layout(binding=0) uniform debugline_vs_params {
    mat4 mvp;
};

out vec4 v_col;

void main() {
    gl_Position = mvp * vec4(a_pos, 1.0);
    v_col = a_col;
}

@end

@fs fs_debugline

in vec4 v_col;
out vec4 frag_color;

void main() {
    frag_color = v_col;
}

@end

@program debugline vs_debugline fs_debugline
