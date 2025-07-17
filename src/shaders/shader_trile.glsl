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
    vec3 pos_after_adjust = vpos - fnormal.xyz * 0.02;
    int count = 0;
    vec4 trixel_material;
    while (count < 5) {
        int xpos = int(clamp(pos_after_adjust.z, 0.0001, 0.99999) * 16.0);
        int ypos = int(clamp(pos_after_adjust.y, 0.0001, 0.99999) * 16.0);
        int zpos = int(clamp(pos_after_adjust.x, 0.0001, 0.99999) * 16.0);

        trixel_material = texelFetch(sampler2D(triletex, trilesmp), ivec2(xpos, ypos + zpos * 16), 0);
        if (length(trixel_material) > 0.01) break; // @ToDo: Replace with proper null trixel check.
        pos_after_adjust += to_center * 0.1;
        count++;
    }
    // frag_color = vec4(vec3(length(to_center)), 1.0);
    frag_color = vec4(trixel_material.xyz, 1.0);
}
@end

@program trile vs_trile fs_trile
