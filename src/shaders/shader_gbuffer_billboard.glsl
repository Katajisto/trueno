@vs vs_gbuffer_billboard

in vec3 position;

layout(binding=0) uniform gbuffer_billboard_vs_params {
    mat4 mvp;
    vec4 uvs;
    vec3 offset;
    vec2 size;
    vec3 cam;
    mat4 view_matrix;
};

out vec2 uv_in;
out vec3 view_space_pos;
out vec3 view_space_normal;

void main() {
    vec3 local_pos = vec3((position.x - 0.5) * size.x, (position.y) * size.y, position.z);
    vec3 world_up = vec3(0.0, 1.0, 0.0);
    vec3 look_dir = offset - cam;
    look_dir.y = 0.0;
    look_dir = normalize(look_dir);
    vec3 world_right = normalize(cross(world_up, look_dir));
    vec3 world_pos = offset + (world_right * local_pos.x) + (world_up * local_pos.y);
    gl_Position = mvp * vec4(world_pos, 1.0);
    vec4 view_pos_4 = view_matrix * vec4(world_pos, 1.0);
    view_space_pos = view_pos_4.xyz;
    view_space_normal = mat3(view_matrix) * vec3(0,1,0);
    uv_in = vec2(uvs.x + position.x * uvs.z, uvs.y + position.y * uvs.w);
}
@end

@fs fs_gbuffer_billboard

in vec2 uv_in;
in vec3 view_space_pos;
in vec3 view_space_normal;

layout(binding = 0) uniform texture2D gsprite;
layout(binding = 0) uniform sampler gspritesmp;

layout(location=0) out vec4 out_position;
layout(location=1) out vec4 out_normal;

void main() {
    vec2 uv = uv_in;
    #if SOKOL_GLSL
        uv.y = 1.0 - uv.y;
    #endif
    vec4 sampled = texture(sampler2D(gsprite, gspritesmp), uv);
    if(sampled.a < 0.01) discard;
    out_position = vec4(view_space_pos, 1.0);
    out_normal = vec4(normalize(view_space_normal), 1.0);
}

@end

@program gbuffer_billboard vs_gbuffer_billboard fs_gbuffer_billboard
