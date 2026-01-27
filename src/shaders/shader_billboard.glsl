@vs vs_billboard

in vec3 position;

layout(binding=0) uniform billboard_vs_params {
    mat4 mvp;
    vec4 uvs;
    vec3 offset;
    vec2 size;
    vec3 cam;
};

out vec2 uv_in;

void main() {
    vec3 local_pos = vec3((position.x - 0.5) * size.x, (position.y) * size.y, position.z);
    vec3 world_up = vec3(0.0, 1.0, 0.0);
    vec3 look_dir = offset - cam;
    look_dir.y = 0.0;
    look_dir = normalize(look_dir);
    vec3 world_right = normalize(cross(world_up, look_dir));
    vec3 world_pos = offset + (world_right * local_pos.x) + (world_up * local_pos.y);
    gl_Position = mvp * vec4(world_pos, 1.0);
    uv_in = vec2(uvs.x + position.x * uvs.z, uvs.y + position.y * uvs.w);
}
@end

@fs fs_billboard

in vec2 uv_in;
out vec4 color;

layout(binding = 0) uniform texture2D sprite;
layout(binding = 0) uniform sampler spritesmp;

void main() {
    vec2 uv = uv_in;
    uv.y = 1.0 - uv.y;
    vec4 sampled = texture(sampler2D(sprite, spritesmp), uv);
    if(sampled.a < 0.01) discard;
    color = vec4(sampled.rgb * 0.5, 1.0);
}

@end

@program billboard vs_billboard fs_billboard
