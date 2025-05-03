@vs vs_trixel

in vec4 position;

layout(binding=0) uniform vs_params {
    mat4 mvp;
};

struct trixel_instance {
    vec4 pos;
};

layout(binding=0) readonly buffer instances {
    trixel_instance inst[];
};


out vec4 color;

void main() {
    vec3 instancepos = inst[gl_InstanceIndex].pos.xyz;
    gl_Position = mvp * (vec4(position.xyz + instancepos, 1.0));
    color = vec4(instancepos, 1.0);
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
