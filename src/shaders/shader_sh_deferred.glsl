@vs vs_sh_deferred
in vec2 position;
in vec2 uv;
out vec2 quad_uv;
void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    quad_uv = uv;
}
@end

@fs fs_sh_deferred

layout(binding=0) uniform texture2D gbuf_worldpos;
layout(binding=1) uniform texture2D gbuf_norm;
layout(binding=2) uniform texture2D sh_chunk;
layout(binding=0) uniform sampler sh_smp;

layout(binding=0) uniform sh_deferred_params {
    mat4 inv_view;
    vec4 chunk_origin;
    vec4 ambient;   // rgb = ambient color, a = ambient intensity
};

in vec2 quad_uv;
out vec4 frag_color;

const float PI = 3.14159265359;

vec3 sh_eval(ivec3 probe, vec3 N) {
    int base = probe.x * 3;
    int row  = probe.z * 32 + probe.y;
    vec4 t0 = texelFetch(sampler2D(sh_chunk, sh_smp), ivec2(base,   row), 0);
    vec4 t1 = texelFetch(sampler2D(sh_chunk, sh_smp), ivec2(base+1, row), 0);
    vec4 t2 = texelFetch(sampler2D(sh_chunk, sh_smp), ivec2(base+2, row), 0);
    float x = N.x, y = N.y, z = N.z;
    float r = 0.886227*t0.x + 1.023327*(t0.w*x + t0.y*y + t0.z*z);
    float g = 0.886227*t1.x + 1.023327*(t1.w*x + t1.y*y + t1.z*z);
    float b = 0.886227*t2.x + 1.023327*(t2.w*x + t2.y*y + t2.z*z);
    return max(vec3(r, g, b) / PI, vec3(0.0));
}

float sh_probe_energy(ivec3 probe) {
    int base = probe.x * 3;
    int row  = probe.z * 32 + probe.y;
    vec4 t0 = texelFetch(sampler2D(sh_chunk, sh_smp), ivec2(base,   row), 0);
    vec4 t1 = texelFetch(sampler2D(sh_chunk, sh_smp), ivec2(base+1, row), 0);
    vec4 t2 = texelFetch(sampler2D(sh_chunk, sh_smp), ivec2(base+2, row), 0);
    return max(0.886227 * (t0.x + t1.x + t2.x), 0.0);
}

vec3 sh_eval_trilinear(ivec3 p0, ivec3 p1, vec3 t, vec3 N) {
    float wx[2] = float[2](1.0 - t.x, t.x);
    float wy[2] = float[2](1.0 - t.y, t.y);
    float wz[2] = float[2](1.0 - t.z, t.z);
    vec3  result     = vec3(0.0);
    vec3  unweighted = vec3(0.0);
    float total_w    = 0.0;
    for (int iz = 0; iz < 2; iz++) {
        for (int iy = 0; iy < 2; iy++) {
            for (int ix = 0; ix < 2; ix++) {
                ivec3 probe = ivec3(
                    ix == 0 ? p0.x : p1.x,
                    iy == 0 ? p0.y : p1.y,
                    iz == 0 ? p0.z : p1.z
                );
                vec3  sh   = sh_eval(probe, N);
                float triw = wx[ix] * wy[iy] * wz[iz];
                float w    = triw * sh_probe_energy(probe);
                result     += sh * w;
                unweighted += sh * triw;
                total_w    += w;
            }
        }
    }
    vec3 amb = ambient.rgb * ambient.a;
    return total_w > 0.001 ? result / total_w : max(unweighted, amb);
}

void main() {
    vec4 wp_sample = texture(sampler2D(gbuf_worldpos, sh_smp), quad_uv);
    if (wp_sample.a < 0.5) discard;

    vec3 world_pos = wp_sample.xyz;

    vec3 cmin = chunk_origin.xyz;
    vec3 cmax = cmin + vec3(32.0);
    if (any(lessThan(world_pos, cmin)) || any(greaterThanEqual(world_pos, cmax))) discard;

    vec3 view_norm  = normalize(texture(sampler2D(gbuf_norm, sh_smp), quad_uv).xyz);
    vec3 world_norm = normalize(mat3(inv_view) * view_norm);

    const float SH_PAD     = 2.0;
    const float SH_SPACING = (32.0 + 2.0 * SH_PAD) / 32.0;
    vec3 probe_f = clamp((world_pos - (cmin - vec3(SH_PAD))) / SH_SPACING, vec3(0.0), vec3(31.0));
    ivec3 p0 = ivec3(floor(probe_f));
    ivec3 p1 = min(p0 + ivec3(1), ivec3(31));

    frag_color = vec4(sh_eval_trilinear(p0, p1, fract(probe_f), world_norm), 1.0);
}
@end

@program sh_deferred vs_sh_deferred fs_sh_deferred
