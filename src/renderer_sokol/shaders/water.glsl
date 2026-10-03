@vs vs_water
@include_block view
@include_block quad

layout(binding=1) uniform water_vs_params {
    float height;
    float half_size;
};

out vec3 v_to_camera;
out vec3 v_world;
out vec2 v_xz;

void main() {
    v_xz = camera.xz + (quad_corner(gl_VertexIndex) * 2.0 - 1.0) * half_size;
    vec3 world = vec3(v_xz.x, height, v_xz.y);
    gl_Position = view_proj * vec4(world, 1.0);
    v_to_camera = camera.xyz - world;
    v_world     = world;
}
@end

@fs fs_water_floor
@include_block scene_out
in vec3 v_to_camera;
in vec3 v_world;
in vec2 v_xz;

layout(binding=2) uniform water_floor_params {
    vec3 floor_color;
};

void main() {
    frag_color = vec4(floor_color, 1.0);
    write_scene(v_to_camera, 0.0);
}
@end

@fs fs_water
@include_block shadow
@include_block transparent_out
in vec3 v_to_camera;
in vec3 v_world;
in vec2 v_xz;

layout(binding=2) uniform water_fs_params {
    vec3 water_color;
    vec3 sun_direction; float shininess;
    vec3 sun_color;     float time;
    float reflectivity;
    float distortion;
};

layout(binding=0) uniform texture2D reflection;
layout(binding=1) uniform texture2D normals;
layout(binding=2) uniform texture2D reflection_glow;
layout(binding=0) uniform sampler reflection_smp;
layout(binding=1) uniform sampler normals_smp;

void main() {
    vec2 flow = time * vec2(-0.005, -0.012);
    vec3 n1 = texture(sampler2D(normals, normals_smp), v_xz * 0.4 + flow * 1.5).xzy * 2.0 - 1.0;
    vec3 n2 = texture(sampler2D(normals, normals_smp), v_xz * 0.1 + flow * 1.7).xzy * 2.0 - 1.0;
    vec3 normal = normalize(n1 + n2);
    vec3 view_dir = normalize(v_to_camera);

    float facing  = max(dot(view_dir, normal), 0.0);
    float fresnel = min(1.0, 0.02 + 0.98 * pow(1.0 - facing, 5.0) + 0.45);

    vec2 screen = gl_FragCoord.xy / vec2(textureSize(sampler2D(reflection, reflection_smp), 0));
    vec2 reflect_uv = vec2(screen.x, 1.0 - screen.y) + normal.xz * distortion;
    vec3 reflected  = texture(sampler2D(reflection, reflection_smp), reflect_uv).rgb;

    float reflect_amount = mix(fresnel, 1.0, reflectivity);
    vec3 color  = mix(water_color, reflected, reflect_amount);
    float alpha = mix(mix(0.3, 0.5, fresnel), 1.0, reflectivity);

    vec3 halfway = normalize(view_dir + sun_direction);
    vec3 sun     = sun_shadow(v_world, vec3(0.0, 1.0, 0.0));
    float glint  = smoothstep(0.5, 0.55, pow(max(dot(normal, halfway), 0.0), shininess)) * brightest(sun);
    float reflected_glow = texture(sampler2D(reflection_glow, reflection_smp), reflect_uv).r * reflect_amount;
    write_transparent(vec4(mix(color, sun_color, glint), max(alpha, glint)), max(glint, reflected_glow));
}
@end

@program water_floor vs_water fs_water_floor
@program water vs_water fs_water
