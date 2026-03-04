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

mat3 gbuf_rot_x(float a) { float c=cos(a),s=sin(a); return mat3(1,0,0, 0,c,-s, 0,s,c); }
mat3 gbuf_rot_z(float a) { float c=cos(a),s=sin(a); return mat3(c,-s,0, s,c,0, 0,0,1); }
mat3 gbuf_rot_y(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s, 0,1,0, -s,0,c); }

mat3 gbuf_get_orientation_matrix(int ori) {
    int face  = ori / 4;
    int twist = ori % 4;
    float PI  = 3.1415927;
    mat3 base;
    if      (face == 0) base = mat3(1.0);
    else if (face == 1) base = gbuf_rot_x(PI);
    else if (face == 2) base = gbuf_rot_z(-PI*0.5);
    else if (face == 3) base = gbuf_rot_z( PI*0.5);
    else if (face == 4) base = gbuf_rot_x( PI*0.5);
    else                base = gbuf_rot_x(-PI*0.5);
    return base * gbuf_rot_y(float(twist) * PI * 0.5);
}

void main() {
    if (isGround == 1) {
        vec4 world_pos = vec4(position.x * 100.0, planeHeight, position.z * 100.0, 1.0);
        vec4 view_pos_4 = view_matrix * world_pos;
        gl_Position = mvp * world_pos;
        view_space_pos = view_pos_4.xyz;
        view_space_normal = mat3(view_matrix) * normal.xyz;
    } else {
        int ori      = int(round(instance.w));
        mat3 rot     = gbuf_get_orientation_matrix(ori);
        vec3 local   = position.xyz - 0.5;
        vec3 rotated = rot * local + 0.5;
        vec4 world_pos   = vec4(rotated + instance.xyz, 1.0);
        vec4 view_pos_4  = view_matrix * world_pos;
        gl_Position      = mvp * world_pos;
        view_space_pos   = view_pos_4.xyz;
        view_space_normal = mat3(view_matrix) * (rot * normal.xyz);
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
