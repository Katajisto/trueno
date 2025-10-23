@vs vs_g
layout(binding=0) uniform gbuffer_vs_params {
    mat4 mvp;
    mat4 view_matrix;
    int isGround;
    float planeHeight;
};

in vec4 position;
in vec4 normal;
in vec4 centre;
in vec4 instance;

out vec3 view_space_pos;
out vec3 view_space_normal;

void main() {
    if (isGround == 1) {
        vec4 world_pos = vec4(position.x * 100.0, planeHeight, position.z * 100.0, 1.0);
        vec4 view_pos_4 = view_matrix * world_pos;
        gl_Position = mvp * world_pos;
        view_space_pos = view_pos_4.xyz;
        view_space_normal = mat3(view_matrix) * normal.xyz;
    } else {
        vec4 world_pos = vec4(position.xyz + instance.xyz, 1.0);
        vec4 view_pos_4 = view_matrix * world_pos;
        gl_Position = mvp * world_pos;
        view_space_pos = view_pos_4.xyz;
        view_space_normal = mat3(view_matrix) * normal.xyz;
        
    }
}
@end

@fs fs_g

in vec3 view_space_pos;
in vec3 view_space_normal;

layout(location=0) out vec4 out_position;
layout(location=1) out vec4 out_normal;

void main() {
    out_position = vec4(view_space_pos, 1.0);
    out_normal = vec4(normalize(view_space_normal), 1.0);
}
@end

@program gbuffer vs_g fs_g
