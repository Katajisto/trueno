@vs vs_dof_blur
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_dof_blur
in vec2 texcoord;
out vec4 frag_color;

layout(binding=0) uniform dof_blur_params {
    float bokeh_radius_x;
    float bokeh_radius_y;
};

layout(binding = 0) uniform texture2D dof_blur_src;
layout(binding = 0) uniform sampler dof_blur_src_smp;

void main() {
    const int   NUM_SAMPLES  = 32;
    const float GOLDEN_ANGLE = 2.39996323;

    vec4  best     = texture(sampler2D(dof_blur_src, dof_blur_src_smp), texcoord);
    float best_lum = dot(best.rgb, vec3(0.2126, 0.7152, 0.0722));

    for (int i = 0; i < NUM_SAMPLES; i++) {
        float theta  = float(i) * GOLDEN_ANGLE;
        float r      = sqrt(float(i) / float(NUM_SAMPLES - 1) + 0.001);
        vec2  offset = vec2(cos(theta), sin(theta)) * r * vec2(bokeh_radius_x, bokeh_radius_y);
        vec4  s      = texture(sampler2D(dof_blur_src, dof_blur_src_smp), texcoord + offset);
        float lum    = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
        if (lum > best_lum) {
            best     = s;
            best_lum = lum;
        }
    }

    frag_color = best;
}
@end

@program dof_blur vs_dof_blur fs_dof_blur
