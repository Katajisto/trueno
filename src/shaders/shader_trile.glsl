@vs vs_trile

in vec4 position;
in vec4 normal;
in vec4 centre;
in vec4 instance;

layout(binding=0) uniform trile_vs_params {
    mat4 mvp;
    mat4 mvp_shadow;
    vec3 camera;
};

out vec3 cam;
out vec3 to_center;
out vec3 vpos;
out vec3 ipos;
out vec4 fnormal;
out vec3 orig_normal;
out vec3 trileCenter;
out vec3 cv;

mat3 rot_x(float a) { float c=cos(a),s=sin(a); return mat3(1,0,0, 0,c,-s, 0,s,c); }
mat3 rot_y(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s, 0,1,0, -s,0,c); }
mat3 rot_z(float a) { float c=cos(a),s=sin(a); return mat3(c,-s,0, s,c,0, 0,0,1); }

mat3 get_orientation_matrix(int ori) {
    int face  = ori / 4;
    int twist = ori % 4;
    float PI  = 3.1415927;
    mat3 base;
    if      (face == 0) base = mat3(1.0);
    else if (face == 1) base = rot_x(PI);
    else if (face == 2) base = rot_z(-PI*0.5);
    else if (face == 3) base = rot_z( PI*0.5);
    else if (face == 4) base = rot_x( PI*0.5);
    else                base = rot_x(-PI*0.5);
    return base * rot_y(float(twist) * PI * 0.5);
}

void main() {
    int ori      = int(round(instance.w));
    mat3 rot     = get_orientation_matrix(ori);
    vec3 local   = position.xyz - 0.5;
    vec3 rotated = rot * local + 0.5;

    gl_Position = mvp * vec4(rotated + instance.xyz, 1.0);
    fnormal     = vec4(rot * normal.xyz, 0.0);
    orig_normal = normal.xyz;
    to_center   = centre.xyz - position.xyz;
    vpos        = rotated + instance.xyz;
    ipos        = position.xyz;
    cam         = camera;
    cv          = normalize(camera - vpos);
    trileCenter = instance.xyz + vec3(0.5);
}
@end

@fs fs_trile

layout(binding=1) uniform trile_world_config {
    vec3 skyBase;
    vec3 skyTop;
    vec3 sunDisk;
    vec3 horizonHalo;
    vec3 sunHalo;
    vec3 sunLightColor;
    vec3 sunPosition;
    float sunIntensity;
    float skyIntensity;

    int hasClouds;

    float planeHeight;
    int animatePlaneHeight;
    vec3 waterColor;
    vec3 deepColor;

    float time;
    int   hsv_lighting;
};

in vec3 cam;
in vec3 to_center;
in vec3 vpos;
in vec3 ipos;
in vec4 fnormal;
in vec3 orig_normal;
in vec3 trileCenter;
in vec3 cv;
out vec4 frag_color;

layout(binding=3) uniform trile_fs_params {
    mat4  mvp_shadow;
    int   is_reflection;
    int   screen_h;
    int   screen_w;
    int   rdm_enabled;
    float ambient_intensity;
    float emissive_scale;
    float rdm_diff_scale;
    float rdm_spec_scale;
    vec3  ambient_color;
    int   is_preview;
    vec3  rdm_tint;
    float rdm_diff_saturation;
    int   sh_enabled;
};

layout(binding = 0) uniform texture2D triletex;
layout(binding = 0) uniform sampler trilesmp;
layout(binding = 1) uniform texture2D ssaotex;
layout(binding = 1) uniform sampler ssaosmp;
layout(binding = 2) uniform texture2D shadowtex;
layout(binding = 2) uniform sampler shadowsmp;
layout(binding = 3) uniform texture2D rdm_lookup;
layout(binding = 4) uniform texture2D rdm_atlas;
layout(binding = 5) uniform texture2D brdf_lut;
layout(binding = 6) uniform texture2D sh_chunk;
layout(binding = 3) uniform sampler rdmsmp;

const float PI = 3.1415927;

const float ROUGHNESS_RAYMARCH_MAX = 0.2; // Below this roughness, actually try to get sharp reflection from RDM.
const float ROUGHNESS_SPEC_CUTOFF = 0.7;  // Above this roughness, disregard RDM specular lighting entirely.

// ---- SKY ----

const float cirrus = 0.5;

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise(vec3 x) {
    vec3 f = fract(x);
    float n = dot(floor(x), vec3(1.0, 157.0, 113.0));
    return mix(mix(mix(hash(n +   0.0), hash(n +   1.0), f.x),
                   mix(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
               mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
                   mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

const mat3 fbm_m = mat3(0.0, 1.60, 1.20, -1.6, 0.72, -0.96, -1.2, -0.96, 1.28);

vec3 sky(vec3 skypos, vec3 sunpos) {
    vec3 npos = normalize(skypos);
    float sDist = dot(npos, normalize(sunpos));

    vec3 skyGradient = mix(skyBase, skyTop, clamp(npos.y * 2.0, 0.0, 0.7));
    vec3 result = skyGradient;

    result += sunHalo * clamp((sDist - 0.95) * 10.0, 0.0, 0.8) * 0.2;

    if (sDist > 0.9999)
        result = sunDisk;

    result += mix(horizonHalo, vec3(0.0), clamp(abs(npos.y) * 80.0, 0.0, 1.0)) * 0.1;
    return result;
}

vec3 sky_reflect(vec3 R, vec3 sunpos) {
    if (R.y < 0.0) R = reflect(R, vec3(0.0, 1.0, 0.0));
    return sky(R, sunpos);
}

// ---- PBR ----

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a  = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx1 = NdotL / (NdotL * (1.0 - k) + k);
    float ggx2 = NdotV / (NdotV * (1.0 - k) + k);
    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// ---- RDM HELPERS ----

// Hemioct encoding (Cigolle2014)
vec2 rdm_hemioct(vec3 v, int face) {
    vec3 vc = v;
    if (face / 2 == 0) { vc.z = v.y; vc.y = v.z; }
    if (face / 2 == 2) { vc.z = v.x; vc.x = v.z; }
    if (face % 2 == 1) { vc.z *= -1.0; }

    vec2 p = vc.xy * (1.0 / (abs(vc.x) + abs(vc.y) + vc.z));
    return vec2(p.x + p.y, p.x - p.y) * 0.5 + 0.5;
}

int rdm_face_from_normal(vec3 N) {
    vec3 a = abs(N);
    if (a.y >= a.x && a.y >= a.z) return N.y >= 0.0 ? 0 : 1;
    if (a.z >= a.x && a.z >= a.y) return N.z >= 0.0 ? 2 : 3;
    return N.x >= 0.0 ? 4 : 5;
}

vec4 rdm_atlas_rect(ivec3 local_pos, int roughness) {
    int rdm_index = local_pos.x + local_pos.y * 32 + local_pos.z * 1024 + roughness * 32768;
    return texelFetch(sampler2D(rdm_lookup, trilesmp), ivec2(rdm_index % 512, rdm_index / 512), 0);
}

ivec2 rdm_face_offset(vec4 rect, int face, int rdmSize, ivec2 atlasSize) {
    int col = face % 2;
    int row = face / 2;
    return ivec2(int(rect.x * float(atlasSize.x)) + col * rdmSize,
                 int(rect.y * float(atlasSize.y)) + row * rdmSize);
}

vec2 rdm_face_uv(int face) {
    if (face <= 1) return vec2(ipos.x, ipos.z);
    if (face <= 3) return vec2(ipos.x, ipos.y);
    return vec2(ipos.z, ipos.y);
}

// ---- RDM SPECULAR ----

vec3 rdm_spec_raymarch(vec3 N, vec3 V, vec3 diff, int face, ivec2 faceOffset, int rdmSize, vec2 atlasInvSize) {
    vec3 reflected = reflect(V, N);
    float maxDist = 20.0;
    int steps = 40;
    float stepSize = maxDist / float(steps);

    for (int i = 0; i < steps; i++) {
        float t = stepSize * float(i + 1);
        vec3 samplePos = diff + t * reflected;
        if (dot(samplePos, N) < 0.0) continue;

        vec3 dir = normalize(samplePos);
        vec2 hemiUV = rdm_hemioct(dir, face);
        vec2 texCoord = (vec2(faceOffset) + hemiUV * float(rdmSize)) * atlasInvSize;
        vec4 s = texture(sampler2D(rdm_atlas, rdmsmp), texCoord, 0);

        float dist = length(samplePos);
        if (s.a > 0.0 && s.a < dist && s.a + stepSize > dist)
            return s.rgb;
    }

    return sky_reflect(reflected, sunPosition);
}

vec3 rdm_spec_single(vec3 N, vec3 V, vec3 diff, int face, ivec2 faceOffset, int rdmSize, vec2 atlasInvSize) {
    vec3 reflected = reflect(V, N);
    vec3 sampleDir = normalize(diff + 2.0 * reflected);
    vec2 hemiUV = rdm_hemioct(sampleDir, face);
    vec2 texCoord = (vec2(faceOffset) + hemiUV * float(rdmSize)) * atlasInvSize;
    return texture(sampler2D(rdm_atlas, rdmsmp), texCoord).rgb;
}

vec3 rdm_sample_diff_probe(vec3 N, ivec3 local_pos, vec3 fallback) {
    vec4 rect = rdm_atlas_rect(local_pos, 7);
    if (rect.z <= 0.0) return fallback;

    int face = rdm_face_from_normal(N);
    int rdmSize = int(pow(2.0, float((7 - 7) + 1)));
    ivec2 atlasSize = textureSize(sampler2D(rdm_atlas, rdmsmp), 0);
    ivec2 fOff = rdm_face_offset(rect, face, rdmSize, atlasSize);
    vec2 pos = rdm_hemioct(N, face);
    return texelFetch(sampler2D(rdm_atlas, rdmsmp),
                      ivec2(fOff.x + int(pos.x * float(rdmSize)),
                            fOff.y + int(pos.y * float(rdmSize))), 0).rgb;
}

int isign(float f) { return f < 0.0 ? -1 : 1; }

vec3 smix(vec3 a, vec3 b, float t) {
    float power = 1.6;
    float st = pow(t, power) / (pow(t, power) + pow(1.0 - t, power));
    return mix(a, b, st);
}

vec3 rdm_indirect_diffuse(vec3 N, vec3 diff, ivec3 local_pos) {
    int face = rdm_face_from_normal(N);
    vec3 ambient = vec3(0.3, 0.3, 0.4);

    vec2 delta;
    if      (face <= 1) delta = vec2(diff.x, diff.z);
    else if (face <= 3) delta = vec2(diff.x, diff.y);
    else                delta = vec2(diff.z, diff.y);

    ivec3 s1, s2, s3;
    if (face <= 1) {
        s1 = ivec3(isign(delta.x), 0, 0);
        s2 = ivec3(0, 0, isign(delta.y));
        s3 = ivec3(isign(delta.x), 0, isign(delta.y));
    } else if (face <= 3) {
        s1 = ivec3(isign(delta.x), 0, 0);
        s2 = ivec3(0, isign(delta.y), 0);
        s3 = ivec3(isign(delta.x), isign(delta.y), 0);
    } else {
        s1 = ivec3(0, 0, isign(delta.x));
        s2 = ivec3(0, isign(delta.y), 0);
        s3 = ivec3(0, isign(delta.y), isign(delta.x));
    }

    vec3 p0 = rdm_sample_diff_probe(N, clamp(local_pos,           ivec3(0), ivec3(31)), ambient);
    vec3 p1 = rdm_sample_diff_probe(N, clamp(local_pos + s1,     ivec3(0), ivec3(31)), ambient);
    vec3 p2 = rdm_sample_diff_probe(N, clamp(local_pos + s2,     ivec3(0), ivec3(31)), ambient);
    vec3 p3 = rdm_sample_diff_probe(N, clamp(local_pos + s1 + s2,ivec3(0), ivec3(31)), ambient);

    return smix(smix(p0, p1, abs(delta.x)),
                smix(p2, p3, abs(delta.x)),
                abs(delta.y));
}

// ---- SH PROBE GRID ----
// Each probe stores 27 L2 SH coefficients (9 per RGB channel), packed into
// 3 RGBA16F texels per probe along the X axis of a 192x4096 2D texture.
// Row = probe.z * 64 + probe.y, col = probe.x * 3 + k.
// Texel layout per probe (px,py,pz):
//   t0: R.c0-3   t1: G.c0-3   t2: B.c0-3
// Probe index from chunk-local world position p (0..32 range):
//   ivec3(floor(p * 2.0)) clamped to [0,63]
// SH evaluation: Lambertian irradiance (L1 only), A0=PI, A1=2PI/3.

vec3 sh_eval(ivec3 probe, vec3 N) {
    int base = probe.x * 3;
    int row  = probe.z * 64 + probe.y;
    vec4 t0 = texelFetch(sampler2D(sh_chunk, rdmsmp), ivec2(base,   row), 0);
    vec4 t1 = texelFetch(sampler2D(sh_chunk, rdmsmp), ivec2(base+1, row), 0);
    vec4 t2 = texelFetch(sampler2D(sh_chunk, rdmsmp), ivec2(base+2, row), 0);

    float x = N.x, y = N.y, z = N.z;
    float r = 0.886227*t0.x + 1.023327*(t0.w*x + t0.y*y + t0.z*z);
    float g = 0.886227*t1.x + 1.023327*(t1.w*x + t1.y*y + t1.z*z);
    float b = 0.886227*t2.x + 1.023327*(t2.w*x + t2.y*y + t2.z*z);

    return max(vec3(r, g, b) / PI, vec3(0.0));
}

// Sum of L0 irradiance across RGB — proxy for total incoming energy.
// Near-zero means the probe is buried inside solid geometry.
float sh_probe_energy(ivec3 probe) {
    int base = probe.x * 3;
    int row  = probe.z * 64 + probe.y;
    vec4 t0 = texelFetch(sampler2D(sh_chunk, rdmsmp), ivec2(base,   row), 0);
    vec4 t1 = texelFetch(sampler2D(sh_chunk, rdmsmp), ivec2(base+1, row), 0);
    vec4 t2 = texelFetch(sampler2D(sh_chunk, rdmsmp), ivec2(base+2, row), 0);
    return max(0.886227 * (t0.x + t1.x + t2.x), 0.0);
}

// Trilinear SH evaluation with confidence weighting.
// Probes with near-zero energy (buried in geometry) are downweighted
// so they don't pull the result toward black.
vec3 sh_eval_trilinear(ivec3 p0, ivec3 p1, vec3 t, vec3 N) {
    float wx[2] = float[2](1.0 - t.x, t.x);
    float wy[2] = float[2](1.0 - t.y, t.y);
    float wz[2] = float[2](1.0 - t.z, t.z);

    vec3  result  = vec3(0.0);
    float total_w = 0.0;

    for (int iz = 0; iz < 2; iz++) {
        for (int iy = 0; iy < 2; iy++) {
            for (int ix = 0; ix < 2; ix++) {
                ivec3 probe = ivec3(
                    ix == 0 ? p0.x : p1.x,
                    iy == 0 ? p0.y : p1.y,
                    iz == 0 ? p0.z : p1.z
                );
                float w = wx[ix] * wy[iy] * wz[iz] * sh_probe_energy(probe);
                result  += sh_eval(probe, N) * w;
                total_w += w;
            }
        }
    }

    return total_w > 0.001 ? result / total_w : vec3(0.0);
}

// ---- HSV ----

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ---- MAIN ----

void main() {
    if (vpos.y < planeHeight - 0.01 && is_reflection == 1) discard;

    // Get trixel material.
    vec3 sample_pos = ipos - orig_normal * 0.02;
    vec4 trixel_material;
    int maxSteps = is_reflection == 1 ? 1 : 3;
    for (int i = 0; i < maxSteps; i++) {
        ivec2 texel = ivec2(
            int(clamp(sample_pos.z, 0.0001, 0.99999) * 16.0),
            int(clamp(sample_pos.y, 0.0001, 0.99999) * 16.0) +
            int(clamp(sample_pos.x, 0.0001, 0.99999) * 16.0) * 16
        );
        trixel_material = texelFetch(sampler2D(triletex, trilesmp), texel, 0);
        if (dot(trixel_material, trixel_material) > 0.0001) break;
        sample_pos += to_center * 0.1;
    }

    vec3 albedo = trixel_material.xyz;

    int packed = int(round(trixel_material.w * 255.0));
    float emittance    = 0.0;
    int   roughnessInt = 0;
    float roughness    = 0.0;
    float metallic     = 0.0;

    if ((packed & 0x1) != 0) {
        emittance = float((packed >> 1) & 0x7F) / 127.0;
    } else {
        roughnessInt = (packed >> 5) & 0x7;
        roughness    = max(float(roughnessInt) / 7.0, 0.05);
        metallic     = float((packed >> 3) & 0x3) / 3.0;
    }

    // Avoid noise in normals which appears for some reason.
    vec3 absN = abs(fnormal.xyz);
    vec3 N;
    if      (absN.x >= absN.y && absN.x >= absN.z) N = vec3(sign(fnormal.x), 0.0, 0.0);
    else if (absN.y >= absN.x && absN.y >= absN.z) N = vec3(0.0, sign(fnormal.y), 0.0);
    else                                            N = vec3(0.0, 0.0, sign(fnormal.z));

    // Simplified lighting evaluation for planar reflection.
    if (is_reflection == 1) {
        vec3 L = normalize(sunPosition);
        float NdotL = max(dot(N, L), 0.0);
        frag_color = vec4(albedo * (NdotL * sunLightColor * sunIntensity + 0.1), 1.0);
        return;
    }

    // ---- 1. VIEW / LIGHT VECTORS ----
    vec3 V = normalize(cam - vpos);
    vec3 L = normalize(sunPosition);
    vec3 H = normalize(V + L);
    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    // ---- 2. PBR TERMS ----
    vec3 F0 = mix(vec3(0.04), albedo, metallic);
    vec3 F  = fresnelSchlick(HdotV, F0);
    float NDF = DistributionGGX(N, H, roughness);
    float G   = GeometrySmith(N, V, L, roughness);
    vec3 kD   = (1.0 - F) * (1.0 - metallic);

    // ---- 3. DIRECT LIGHT (sun + shadow) ----
    vec4 light_proj = mvp_shadow * vec4(floor(vpos * 16.0) / 16.0, 1.0);
    vec3 light_ndc  = light_proj.xyz / light_proj.w * 0.5 + 0.5;
    light_ndc.z -= 0.001;
    float shadow = texture(sampler2DShadow(shadowtex, shadowsmp), light_ndc);

    vec3 direct_specular = (NDF * G * F) / (4.0 * NdotV * NdotL + 0.0001);
    vec3 light = shadow * (kD * albedo / PI + direct_specular) * NdotL * sunLightColor * sunIntensity;

    // ---- 4. INDIRECT LIGHT (RDM / SH / ambient fallback) ----
    ivec3 local     = ivec3(mod(floor(trileCenter), 32.0));
    vec4 atlas_rect = rdm_atlas_rect(local, roughnessInt);
    float ssao      = texture(sampler2D(ssaotex, rdmsmp),
                              gl_FragCoord.xy / vec2(float(screen_w), float(screen_h))).r;
    vec3 emissive   = albedo * emittance * emissive_scale;

    if (rdm_enabled == 1) {
        vec3 Frough        = FresnelSchlickRoughness(NdotV, F0, roughness);
        vec3 hemispherePos = trileCenter + N * 0.49;
        vec3 diff          = vpos - hemispherePos;

        // 4a. Indirect specular.
        //     roughnessInt 0-1 with a baked RDM: ray-march or single-sample into the atlas.
        //     roughnessInt 2+ without RDM data: sky reflection.
        //     roughnessInt > ROUGHNESS_SPEC_CUTOFF: skip specular entirely.
        if (roughnessInt <= 1 && atlas_rect.z > 0.0) {
            int face = rdm_face_from_normal(N);
            ivec2 atlasSize   = textureSize(sampler2D(rdm_atlas, rdmsmp), 0);
            vec2  atlasInvSz  = 1.0 / vec2(atlasSize);
            int   rdmSize     = int(atlas_rect.z * float(atlasSize.x)) / 2;
            ivec2 fOff        = rdm_face_offset(atlas_rect, face, rdmSize, atlasSize);

            vec3 indirectSpec = roughness < ROUGHNESS_RAYMARCH_MAX
                ? rdm_spec_raymarch(N, -cv, diff, face, fOff, rdmSize, atlasInvSz)
                : rdm_spec_single (N, -cv, diff, face, fOff, rdmSize, atlasInvSz);
            indirectSpec *= rdm_tint;

            float specLum = dot(indirectSpec, vec3(0.2126, 0.7152, 0.0722));
            indirectSpec  = mix(indirectSpec, vec3(specLum), metallic);

            vec2  envBRDF       = texture(sampler2D(brdf_lut, rdmsmp), vec2(NdotV, roughness)).rg;
            float roughnessBell = 1.0 - 0.7 * sin(roughness * PI);
            float grazingSuppr  = 1.0 - 0.9 * roughness * sin(roughness * PI) * pow(1.0 - NdotV, 2.0);
            float specRoughFade = 1.0 - clamp((roughness - 0.5) / 0.3, 0.0, 1.0);

            light += indirectSpec * (Frough * envBRDF.x + envBRDF.y)
                   * rdm_spec_scale * roughnessBell * grazingSuppr * specRoughFade;
        } else if (roughness < ROUGHNESS_SPEC_CUTOFF) {
            vec3  R           = reflect(-V, N);
            vec2  envBRDF     = texture(sampler2D(brdf_lut, rdmsmp), vec2(NdotV, roughness)).rg;
            float specRoughFd = 1.0 - clamp((roughness - 0.5) / 0.3, 0.0, 1.0);
            light += sky_reflect(R, sunPosition) * (Frough * envBRDF.x + envBRDF.y)
                   * rdm_spec_scale * specRoughFd;
        }

        // 4b. Indirect diffuse.
        //     SH probe grid when available (trilinear, confidence-weighted).
        //     Falls back to RDM level-7 diffuse probes.
        vec3 indirectDiff;
        if (sh_enabled == 1) {
            vec3  trile_origin = floor(trileCenter);
            vec3  local_frag   = vec3(local) + (vpos - trile_origin);
            vec3  probe_f      = clamp(local_frag * 2.0, vec3(0.0), vec3(63.0));
            ivec3 p0 = ivec3(floor(probe_f));
            ivec3 p1 = min(p0 + ivec3(1), ivec3(63));
            indirectDiff = sh_eval_trilinear(p0, p1, fract(probe_f), N) * rdm_tint;
        } else {
            indirectDiff = rdm_indirect_diffuse(N, diff, local) * rdm_tint;
        }
        float diffLuma = dot(indirectDiff, vec3(0.2126, 0.7152, 0.0722));
        indirectDiff   = mix(vec3(diffLuma), indirectDiff, rdm_diff_saturation);

        light += (1.0 - Frough) * (1.0 - metallic) * indirectDiff / PI * albedo * ssao * rdm_diff_scale;

        // 4c. Ambient floor — kicks in when indirect light is below the configured minimum.
        if (rdm_diff_scale < 0.001 || length(light) < ambient_intensity)
            light += ambient_color * max(ambient_intensity - length(light), 0.0) * albedo * ssao;

    } else {
        // No baked data: flat ambient + sky specular.
        light += ambient_color * ambient_intensity * albedo * ssao;
        light += F * sky_reflect(reflect(-V, N), sunPosition) * 0.1;
    }

    // ---- 5. FINAL COMPOSITE ----
    vec3 final_color = light + emissive;
    frag_color = vec4(mix(deepColor, final_color, smoothstep(0.0, planeHeight, vpos.y)), 1.0);

    if      (is_preview == 1) frag_color.rgb = mix(frag_color.rgb, vec3(0.3, 0.7, 1.0), 0.5);
    else if (is_preview == 2) frag_color.rgb = mix(frag_color.rgb, vec3(1.0, 0.3, 0.2), 0.5);
}
@end

@program trile vs_trile fs_trile
