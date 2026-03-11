@vs vs_trile_shadow

layout(location=0) in vec4 position;
layout(location=1) in vec4 normal;    // same slot as shader_trile; not used
layout(location=2) in vec4 centre;    // same slot as shader_trile; not used
layout(location=3) in vec4 instance;  // xyz=world_pos, w=orientation

layout(binding=0) uniform trile_shadow_vs_params {
    mat4 mvp;
};

mat3 rot_x(float a) { float c=cos(a),s=sin(a); return mat3(1,0,0, 0,c,-s, 0,s,c); }
mat3 rot_z(float a) { float c=cos(a),s=sin(a); return mat3(c,-s,0, s,c,0, 0,0,1); }
mat3 rot_y(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s, 0,1,0, -s,0,c); }

mat3 get_orientation_matrix(int ori) {
    int face  = ori / 4;
    int twist = ori % 4;
    float PI  = 3.1415927;
    mat3 base;
    if      (face == 0) base = mat3(1.0);
    else if (face == 1) base = rot_x(PI);
    else if (face == 2) base = rot_z(-PI*0.5);
    else if (face == 3) base = rot_z( PI*0.5);
    else if (face == 4) base = rot_x( PI*0.5);
    else                base = rot_x(-PI*0.5);
    return base * rot_y(float(twist) * PI * 0.5);
}

void main() {
    int ori      = int(round(instance.w));
    mat3 rot     = get_orientation_matrix(ori);
    vec3 local   = position.xyz - 0.5;
    vec3 rotated = rot * local + 0.5;
    gl_Position  = mvp * vec4(rotated + instance.xyz, 1.0);
}
@end

@fs fs_trile_shadow
out vec4 frag_color;
void main() {
    frag_color = vec4(0.0);
}
@end

@program trile_shadow vs_trile_shadow fs_trile_shadow
