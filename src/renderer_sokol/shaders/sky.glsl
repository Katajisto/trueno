@vs vs_sky
@include_block view
@include_block fullscreen

out vec4 v_point;
out vec3 v_camera;

void main() {
    vec2 p = fullscreen_position(gl_VertexIndex);
    gl_Position = vec4(p, 0.0, 1.0);
    v_point  = inv_view_proj * vec4(p, 0.5, 1.0);
    v_camera = camera.xyz;
}
@end

@fs fs_sky
@include_block scene_out
in vec4 v_point;
in vec3 v_camera;

layout(binding=1) uniform sky_params {
    vec4 sky_base;
    vec4 sky_top;
    vec4 sun_disk;
    vec4 sun_halo;
    vec4 horizon_halo;
    vec4 sun;   // xyz = direction, w = sky intensity
};

void main() {
    vec3 dir = normalize(v_point.xyz / v_point.w - v_camera);
    vec3 color = mix(sky_base.rgb, sky_top.rgb, clamp(dir.y * 2.0, 0.0, 0.7));

    // The sun and its halo are squares in the sun's own frame.
    vec3 sun_dir   = sun.xyz;
    vec3 sun_right = normalize(cross(sun_dir, vec3(0.0, 1.0, 0.0)));
    vec3 sun_up    = cross(sun_right, sun_dir);
    vec3 off       = dir - sun_dir * dot(dir, sun_dir);
    float square   = max(abs(dot(off, sun_right)), abs(dot(off, sun_up)));

    float halo = clamp((0.25 - square) * 6.0, 0.0, 1.0);
    color += sun_halo.rgb * halo * halo;
    bool disk = square < 0.032 && dot(dir, sun_dir) > 0.0;
    if (disk) color = sun_disk.rgb * 3.0;
    color += horizon_halo.rgb * (1.0 - clamp(abs(dir.y) * 20.0, 0.0, 1.0)) * 0.8;

    frag_color = vec4(color * sun.w, 1.0);
    frag_glow  = vec4(disk ? 1.0 : 0.0);
    frag_scene = vec4(1.0e4);
}
@end

@program sky vs_sky fs_sky
