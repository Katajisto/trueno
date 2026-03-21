@vs vs_particle

in vec3 position;
in vec4 inst_pos_size;
in vec4 inst_uv_rect;
in vec4 inst_color;

layout(binding=0) uniform particle_vs_params {
    mat4 mvp;
    vec3 cam;
};

out vec2 uv_in;
out vec4 color_in;

void main() {
    float size = inst_pos_size.w;
    vec3 inst_pos = inst_pos_size.xyz;
    vec3 local_pos = vec3((position.x - 0.5) * size, position.y * size, 0.0);
    vec3 world_up = vec3(0.0, 1.0, 0.0);
    vec3 look_dir = inst_pos - cam;
    look_dir.y = 0.0;
    if (length(look_dir) < 0.0001) look_dir = vec3(1.0, 0.0, 0.0);
    look_dir = normalize(look_dir);
    vec3 world_right = normalize(cross(world_up, look_dir));
    vec3 world_pos = inst_pos + world_right * local_pos.x + world_up * local_pos.y;
    gl_Position = mvp * vec4(world_pos, 1.0);
    uv_in = vec2(inst_uv_rect.x + position.x * inst_uv_rect.z,
                 inst_uv_rect.y + position.y * inst_uv_rect.w);
    color_in = inst_color;
}

@end

@fs fs_particle

in vec2 uv_in;
in vec4 color_in;
out vec4 color;

layout(binding = 0) uniform texture2D particle_sprite;
layout(binding = 0) uniform sampler particle_spritesmp;

void main() {
    vec2 uv = uv_in;
    uv.y = 1.0 - uv.y;
    vec4 sampled = texture(sampler2D(particle_sprite, particle_spritesmp), uv);
    if (sampled.a < 0.01) discard;
    color = sampled * color_in;
}

@end

@program particle vs_particle fs_particle
