@vs vs_trile

in vec4 position;
in vec4 normal;
in vec4 centre;

layout(binding=0) uniform trile_vs_params {
    mat4 mvp;
};


out vec3 to_center;
out vec3 vpos;
out vec4 fnormal;

void main() {
    
    gl_Position = mvp * vec4(position.xyz, 1.0);
    fnormal = normal;
    to_center = centre.xyz - position.xyz;
    vpos = position.xyz;
}
@end

@fs fs_trile

in vec3 to_center;
in vec3 vpos;
in vec4 fnormal;
out vec4 frag_color;

layout(binding = 0) uniform texture2D triletex;
layout(binding = 0) uniform sampler trilesmp;

void main() {
    //frag_color = vec4((fnormal.xyz + vec3(1.0, 1.0, 1.0)) * 0.5, 1.0);
    vec3 pos_after_adjust_f = vpos - fnormal.xyz * 0.01 + normalize(to_center) * 0.01;
    vec3 pos_after_adjust_b = vpos - fnormal.xyz * 0.01 + normalize(to_center) * 0.1;
    int xpos_f = int(clamp(pos_after_adjust_f.z, 0.0001, 0.99999) * 16.0);
    int ypos_f = int(clamp(pos_after_adjust_f.y, 0.0001, 0.99999) * 16.0);
    int zpos_f = int(clamp(pos_after_adjust_f.x, 0.0001, 0.99999) * 16.0);
    int xpos_b = int(clamp(pos_after_adjust_b.z, 0.0001, 0.99999) * 16.0);
    int ypos_b = int(clamp(pos_after_adjust_b.y, 0.0001, 0.99999) * 16.0);
    int zpos_b = int(clamp(pos_after_adjust_b.x, 0.0001, 0.99999) * 16.0);

    vec4 trixel_material_b = texelFetch(sampler2D(triletex, trilesmp), ivec2(xpos_b, ypos_b + zpos_b * 16), 0);
    vec4 trixel_material_f = texelFetch(sampler2D(triletex, trilesmp), ivec2(xpos_f, ypos_f + zpos_f * 16), 0);
    frag_color = vec4(max(trixel_material_f.xyz, trixel_material_b.xyz), 1.0);
    // frag_color = vec4(vec3(length(to_center)), 1.0);
}
@end

@program trile vs_trile fs_trile
