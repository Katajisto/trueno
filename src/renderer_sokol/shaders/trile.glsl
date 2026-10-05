@vs vs_trile
@include_block view

layout(binding=1) uniform trile_params {
    vec4 orientations[72];
    float show_hidden;   // shadow and reflection passes still draw cut triles
};

in vec3 position;
in vec4 data_n;     // bytes / 255: x = swatch, y = ao (0..3), z = normal index
in vec4 instance;   // xyz = position, w = orientation
in float tint;
in float cut;

out float v_clip;
out vec3 v_to_camera;
out vec3 v_world;
out vec3 v_normal;
out float v_swatch;
out float v_facing;
out float v_ao;
out vec3 v_shade;
out vec3 v_sun;
out float v_tint;
out float v_cut;

void main() {
    vec4 data = data_n * 255.0;
    int ori = int(instance.w + 0.5) * 3;
    mat3 rotation = transpose(mat3(orientations[ori].xyz, orientations[ori + 1].xyz, orientations[ori + 2].xyz));
    vec3 world = rotation * (position - 0.5) + 0.5 + instance.xyz;

    int n = int(data.z + 0.5);
    vec3 normal = vec3(0.0);
    normal[n / 2] = (n % 2 == 0) ? 1.0 : -1.0;
    v_normal = rotation * normal;
    v_facing = smoothstep(0.0, 0.3, dot(v_normal, sun_direction.xyz));
    v_ao     = data.y / 3.0;
    v_shade  = shade_color.rgb;
    v_sun    = sun_color.rgb;

    gl_Position = view_proj * vec4(world, 1.0);
    v_cut = show_hidden > 0.5 ? 0.0 : cut;
    // Fully cut triles are collapsed outside the clip volume, so nothing is drawn.
    if (v_cut > 0.999) gl_Position = vec4(0.0, 0.0, 2.0, 1.0);
    v_to_camera = camera.xyz - world;
    v_world     = world;
    v_clip   = dot(vec4(world, 1.0), clip);
    v_swatch = data.x;
    v_tint   = tint;
}
@end

@block trile_in
in float v_clip;
in vec3 v_to_camera;
in vec3 v_world;
in vec3 v_normal;
in float v_swatch;
in float v_facing;
in float v_ao;
in vec3 v_shade;
in vec3 v_sun;
in float v_tint;
in float v_cut;
@end

@block palette
layout(binding=0) uniform texture2D palette;
layout(binding=0) uniform sampler palette_smp;
@end

@fs fs_trile
@include_block scene_out
@include_block emissive
@include_block shadow
@include_block trile_in
@include_block palette

layout(binding=2) uniform trile_fs_params {
    vec4 sun_dir;              // towards the sun
    vec4 probe_min;            // xyz = first chunk in probe_index, w = 1 when there are probes
    vec4 probe_size;           // xyz = probe_index size in chunks
    float use_reflection;      // the reflection pass can't read its own image
    float reflection_height;
};
layout(binding=1) uniform texture2D trile_reflection;
layout(binding=2) uniform texture2D trile_reflection_glow;
layout(binding=1) uniform sampler trile_reflection_smp;
layout(binding=3) uniform texture3D probe_index;   // per chunk: brick number + 1 in r + g * 256, 0 = none
layout(binding=4) uniform texture3D probe_atlas;   // per brick 32^3 probes, 3 texels each: red, green, blue
layout(binding=2) uniform sampler probe_smp;

const float GLOSS_GLOW           = 4.0;   // how much a full gloss highlight blooms
const float REFLECTED_GLOW_CURVE = 0.4;   // below 1, reflected glow fades slower than reflected colour
const float GLASS_PROJECTION     = 2.0;   // how strongly coloured sunlight paints its colour on

const int PROBE_BRICKS_PER_COLUMN = 16;

// The probe at the centre of the trile at cell, unless there is none or it is inside geometry.
bool probe_at(ivec3 cell, out vec4 r, out vec4 g, out vec4 b) {
    ivec3 chunk = ivec3(floor(vec3(cell) / 32.0));
    ivec3 slot  = chunk - ivec3(probe_min.xyz);
    if (any(lessThan(slot, ivec3(0))) || any(greaterThanEqual(slot, ivec3(probe_size.xyz)))) return false;
    vec2 number = texelFetch(sampler3D(probe_index, probe_smp), slot, 0).rg * 255.0 + 0.5;
    int brick = int(number.x) + int(number.y) * 256 - 1;
    if (brick < 0) return false;
    ivec3 local = cell - chunk * 32;
    ivec3 texel = ivec3(local.x * 3, (brick % PROBE_BRICKS_PER_COLUMN) * 32 + local.y, (brick / PROBE_BRICKS_PER_COLUMN) * 32 + local.z);
    r = texelFetch(sampler3D(probe_atlas, probe_smp), texel, 0);
    g = texelFetch(sampler3D(probe_atlas, probe_smp), texel + ivec3(1, 0, 0), 0);
    b = texelFetch(sampler3D(probe_atlas, probe_smp), texel + ivec3(2, 0, 0), 0);
    return r.x >= 0.0;
}

// Light from the eight probes around a point half a trile out from the surface,
// leaving out probes behind the surface or inside geometry. Like sun_shadow it is
// taken at the trixel face centre, so it steps per trixel. a = 0 when no probe counts.
vec4 probe_light(vec3 world, vec3 normal) {
    vec3 half_trixel = normal * (0.5 / 16.0);
    vec3 face = (floor((world - half_trixel) * 16.0) + 0.5) / 16.0 + half_trixel;
    vec3 grid = face + normal * 0.5 - 0.5;
    ivec3 base = ivec3(floor(grid));
    vec3 f = grid - vec3(base);

    vec4 sum_r = vec4(0.0), sum_g = vec4(0.0), sum_b = vec4(0.0);
    float total = 0.0;
    for (int i = 0; i < 8; i++) {
        ivec3 offset = ivec3(i & 1, (i >> 1) & 1, i >> 2);
        ivec3 cell = base + offset;
        if (dot(vec3(cell) + 0.5 - face, normal) < 0.01) continue;
        vec4 r, g, b;
        if (!probe_at(cell, r, g, b)) continue;
        vec3 t = mix(1.0 - f, f, vec3(offset));
        float w = max(t.x * t.y * t.z, 0.0001);
        sum_r += r * w;
        sum_g += g * w;
        sum_b += b * w;
        total += w;
    }
    if (total == 0.0) return vec4(0.0);
    // Irradiance over pi from the SH: the cosine lobe convolved, both bands.
    vec4 lobe = vec4(0.282095, 0.325735 * normal.y, 0.325735 * normal.z, 0.325735 * normal.x);
    return vec4(max(vec3(dot(sum_r, lobe), dot(sum_g, lobe), dot(sum_b, lobe)) / total, 0.0), 1.0);
}

// Ordered dither, so dissolving triles fade without blending.
float dither(vec2 pixel) {
    const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    ivec2 p = ivec2(pixel) % 4;
    return (bayer[p.y * 4 + p.x] + 0.5) / 16.0;
}

void main() {
    if (v_clip < 0.0 || v_cut > dither(gl_FragCoord.xy)) discard;
    int id = int(v_swatch + 0.5);
    vec4 swatch   = texelFetch(sampler2D(palette, palette_smp), ivec2(id, 0), 0);
    vec4 material = texelFetch(sampler2D(palette, palette_smp), ivec2(id, 1), 0);   // g = reflectivity, b = gloss
    vec3 albedo = swatch.rgb;
    if (v_tint > 1.5)      albedo = mix(albedo, vec3(1.0, 0.2, 0.2), 0.5);
    else if (v_tint > 0.5) albedo = mix(albedo, vec3(0.2, 1.0, 0.2), 0.5);
    vec3 sun = v_facing * sun_shadow(v_world, v_normal);
    vec3 lit = sun * mix(0.25, 1.0, v_ao);
    vec4 probe = probe_min.w > 0.5 ? probe_light(v_world, v_normal) : vec4(0.0);
    vec3 shade = v_shade + probe.rgb;
    vec3 light = mix(shade * mix(0.6, 1.0, v_ao), v_sun, lit);
    vec3 color = albedo * light;

    // Light through glass paints the glass colour onto what it hits, so the pattern
    // shows on dark surfaces too, not only where the albedo can reflect it.
    float bright = brightest(sun);
    if (bright > 0.001) {
        float tinted = (bright - min(sun.r, min(sun.g, sun.b))) / bright;
        color = mix(color, sun * v_sun, min(1.0, tinted * GLASS_PROJECTION));
    }
    float glow = swatch.a * EMISSIVE_GLOW;

    // Glossier is both stronger and sharper.
    if (material.b > 0.0) {
        vec3 halfway = normalize(normalize(v_to_camera) + sun_dir.xyz);
        float highlight = pow(max(dot(v_normal, halfway), 0.0), mix(4.0, 96.0, material.b)) * material.b;
        color += v_sun * sun * highlight;
        glow  += highlight * brightest(sun) * GLOSS_GLOW;
    }
    // Only floors lying on the reflection plane can show the planar reflection.
    if (use_reflection > 0.5 && material.g > 0.0 && v_normal.y > 0.5 && abs(v_world.y - reflection_height) < 0.02) {
        vec2 screen = gl_FragCoord.xy / vec2(textureSize(sampler2D(trile_reflection, trile_reflection_smp), 0));
        vec2 uv     = vec2(screen.x, 1.0 - screen.y);
        color = mix(color, texture(sampler2D(trile_reflection, trile_reflection_smp), uv).rgb, material.g);
        glow  = max(glow, texture(sampler2D(trile_reflection_glow, trile_reflection_smp), uv).r * pow(material.g, REFLECTED_GLOW_CURVE));
    }

    // Emissive swatches show their own colour whatever the lighting.
    frag_color = vec4(mix(color, albedo, swatch.a), 1.0);
    write_scene(v_to_camera, glow);
}
@end

@fs fs_trile_shadow
@include_block trile_in
@include_block palette
void main() {
    // Glass lets the sun through.
    if (texelFetch(sampler2D(palette, palette_smp), ivec2(int(v_swatch + 0.5), 1), 0).r > 0.5) discard;
}
@end

// Drawn after the opaque casters and multiplied into the shadow tint, so light
// through several panes takes all their colours.
@fs fs_trile_glass_shadow
@include_block trile_in
@include_block palette
out vec4 frag_color;
void main() {
    int id = int(v_swatch + 0.5);
    if (texelFetch(sampler2D(palette, palette_smp), ivec2(id, 1), 0).r < 0.5) discard;
    vec3 c = texelFetch(sampler2D(palette, palette_smp), ivec2(id, 0), 0).rgb;
    // Tinted rather than darkened: the glass's brightest channel passes fully.
    frag_color = vec4(c / max(max(c.r, max(c.g, c.b)), 0.001), gl_FragCoord.z);
}
@end

@program trile vs_trile fs_trile
@program trile_shadow vs_trile fs_trile_shadow
@program trile_glass_shadow vs_trile fs_trile_glass_shadow
