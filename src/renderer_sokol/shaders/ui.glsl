@vs vs_ui
in vec2 position;
in vec2 uv;
in vec4 color0;

layout(binding=0) uniform ui_vs_params {
    vec2 screen_size;
};

out vec2 v_uv;
out vec4 v_color;

void main() {
    vec2 ndc = position / screen_size * 2.0 - 1.0;
    gl_Position = vec4(ndc.x, -ndc.y, 0.0, 1.0);
    v_uv    = uv;
    v_color = color0;
}
@end

@fs fs_ui
in vec2 v_uv;
in vec4 v_color;
out vec4 frag_color;

layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

void main() {
    frag_color = texture(sampler2D(tex, smp), v_uv) * v_color;
}
@end

@program ui vs_ui fs_ui
