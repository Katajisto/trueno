@vs vs_water
@include_block view
@include_block quad

layout(binding=1) uniform water_vs_params {
    float height;
    float half_size;
};

out vec3 v_to_camera;
out vec4 v_normal_uv;

void main() {
    vec2 xz = camera.xz + (quad_corner(gl_VertexIndex) * 2.0 - 1.0) * half_size;
    vec3 world = vec3(xz.x, height, xz.y);
    gl_Position = view_proj * vec4(world, 1.0);

    vec2 flow = camera.w * vec2(-0.005, -0.012);
    v_normal_uv = vec4(xz * 0.4 + flow * 1.5, xz * 0.1 + flow * 1.7);
    v_to_camera = camera.xyz - world;
}
@end

@fs fs_water
in vec3 v_to_camera;
in vec4 v_normal_uv;
out vec4 frag_color;

layout(binding=2) uniform water_fs_params {
    vec3 color;
    float surface;
    float reflectivity;
    float distortion;
};

layout(binding=0) uniform texture2D reflection;
layout(binding=1) uniform texture2D normals;
layout(binding=0) uniform sampler reflection_smp;
layout(binding=1) uniform sampler normals_smp;

void main() {
    if (surface < 0.5) {
        frag_color = vec4(color, 1.0);
        return;
    }

    vec3 n1 = texture(sampler2D(normals, normals_smp), v_normal_uv.xy).xzy * 2.0 - 1.0;
    vec3 n2 = texture(sampler2D(normals, normals_smp), v_normal_uv.zw).xzy * 2.0 - 1.0;
    vec3 normal = normalize(n1 + n2);

    float facing  = max(dot(normalize(v_to_camera), normal), 0.0);
    float fresnel = min(1.0, 0.02 + 0.98 * pow(1.0 - facing, 5.0) + 0.45);

    vec2 uv = gl_FragCoord.xy / vec2(textureSize(sampler2D(reflection, reflection_smp), 0));
    uv.y = 1.0 - uv.y;
    vec3 reflected = texture(sampler2D(reflection, reflection_smp), uv + normal.xz * distortion).rgb;

    vec3 surface_color = mix(color, reflected, mix(fresnel, 1.0, reflectivity));
    float alpha = mix(mix(0.3, 0.5, fresnel), 1.0, reflectivity);
    frag_color = vec4(surface_color, alpha);
}
@end

@program water vs_water fs_water
