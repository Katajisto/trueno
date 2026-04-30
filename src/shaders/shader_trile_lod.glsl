@vs vs_trile_lod

in vec4 position;
in vec4 normal;
in vec4 color;
in vec4 instance;

layout(binding=0) uniform trile_lod_vs_params {
    mat4 mvp;
    vec3 camera;
};

out vec3 vpos;
out vec3 cam;
out vec3 vcolor;
out vec3 vnorm;

mat3 rot_x(float a) { float c=cos(a),s=sin(a); return mat3(1,0,0, 0,c,-s, 0,s,c); }
mat3 rot_y(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s, 0,1,0, -s,0,c); }
mat3 rot_z(float a) { float c=cos(a),s=sin(a); return mat3(c,-s,0, s,c,0, 0,0,1); }

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

    gl_Position = mvp * vec4(rotated + instance.xyz, 1.0);
    vpos        = rotated + instance.xyz;
    cam         = camera;
    vcolor      = color.xyz;
    vnorm       = rot * normal.xyz;
}
@end

@fs fs_trile_lod

layout(binding=1) uniform trile_lod_fs_params {
    vec3  skyBase;
    vec3  sunPosition;
    vec3  sunLightColor;
    float sunIntensity;
    vec3  ambient_color;
    float ambient_intensity;
    float planeHeight;
    vec3  deepColor;
    int   is_reflection;
    float fog_start;
    float fog_end;
};

in vec3 vpos;
in vec3 cam;
in vec3 vcolor;
in vec3 vnorm;
out vec4 frag_color;

void main() {
    if (vpos.y < planeHeight - 0.01 && is_reflection == 1) discard;

    const float PI = 3.1415927;
    vec3 N = normalize(vnorm);
    vec3 L = normalize(sunPosition);
    float NdotL = max(dot(N, L), 0.0);

    vec3 lit;
    if (is_reflection == 1) {
        lit = vcolor * (NdotL * sunLightColor * sunIntensity + 0.1) / PI;
    } else {
        lit = vcolor * (NdotL * sunLightColor * sunIntensity + ambient_color * ambient_intensity) / PI;
    }

    vec3 final_color = mix(deepColor, lit, smoothstep(0.0, planeHeight, vpos.y));

    float fog_dist   = length(vpos - cam);
    float fog_factor = smoothstep(fog_start, fog_end, fog_dist);
    final_color      = mix(final_color, skyBase, fog_factor);

    frag_color = vec4(final_color, 1.0);
}
@end

@program trile_lod vs_trile_lod fs_trile_lod
