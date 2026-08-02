@vs vs_debugline

// Lines are drawn as camera-facing quads rather than GL lines, so they can have
// a real pixel width. Buffer 0 holds the six corners of a unit quad, buffer 1
// one instance per line.
in vec2 a_corner;   // x = which side (-1 / +1), y = which end (0 = a, 1 = b)
in vec3 a_pos_a;
in vec3 a_pos_b;
in vec4 a_col;
in float a_width;   // in pixels

layout(binding=0) uniform debugline_vs_params {
    mat4 mvp;
    vec4 viewport;  // xy = size in pixels, zw = unused
};

out vec4 v_col;

void main() {
    vec4 clip_a = mvp * vec4(a_pos_a, 1.0);
    vec4 clip_b = mvp * vec4(a_pos_b, 1.0);

    // Widen in screen space so the line keeps its pixel width at any depth.
    // Guard against w <= 0: an endpoint behind the eye has no screen position,
    // so fall back to the other end's and let clipping handle the rest.
    float wa = max(clip_a.w, 0.0001);
    float wb = max(clip_b.w, 0.0001);
    vec2 screen_a = (clip_a.xy / wa) * viewport.xy;
    vec2 screen_b = (clip_b.xy / wb) * viewport.xy;

    vec2 delta = screen_b - screen_a;
    float len = length(delta);
    vec2 dir = (len > 0.0001) ? delta / len : vec2(1.0, 0.0);
    vec2 normal = vec2(-dir.y, dir.x);

    vec4 clip = mix(clip_a, clip_b, a_corner.y);
    // Half a pixel of extra width keeps thin lines from disappearing between
    // sample points.
    vec2 offset = normal * a_corner.x * (a_width * 0.5 + 0.5) / viewport.xy;
    gl_Position = clip + vec4(offset * clip.w, 0.0, 0.0);

    v_col = a_col;
}

@end

@fs fs_debugline

in vec4 v_col;
out vec4 frag_color;

void main() {
    frag_color = v_col;
}

@end

@program debugline vs_debugline fs_debugline
