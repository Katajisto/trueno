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
out vec3 vpos; // The actual position;
out vec3 ipos; // Trile space position;
out vec4 fnormal;
out vec3 orig_normal; // Unrotated object-space normal, used for trixel lookup
out vec3 trileCenter;
out vec3 cv;

mat3 rot_x(float a) { float c=cos(a),s=sin(a); return mat3(1,0,0, 0,c,-s, 0,s,c); }
mat3 rot_z(float a) { float c=cos(a),s=sin(a); return mat3(c,-s,0, s,c,0, 0,0,1); }
mat3 rot_y(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s, 0,1,0, -s,0,c); }

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
    orig_normal = normal.xyz;                    // unrotated, for trixel lookup
    to_center   = centre.xyz - position.xyz;     // unrotated, for trixel lookup
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
layout(binding = 3) uniform sampler rdmsmp;

const float PI = 3.1412854;

// --- SKY START ---

const float cirrus = 0.5;
const float cumulus = 20.0;

float hash(float n)
{
    return fract(sin(n) * 43758.5453123);
}

float noise(vec3 x)
{
    vec3 f = fract(x);
    float n = dot(floor(x), vec3(1.0, 157.0, 113.0));
    return mix(mix(mix(hash(n +   0.0), hash(n +   1.0), f.x),
    mix(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
    mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
    mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

const mat3 m = mat3(0.0, 1.60,  1.20, -1.6, 0.72, -0.96, -1.2, -0.96, 1.28);
float fbm(vec3 p)
{
    float f = 0.0;
    f += noise(p) / 2.0; p = m * p * 1.1;
    f += noise(p) / 4.0; p = m * p * 1.2;
    f += noise(p) / 6.0; p = m * p * 1.3;
    f += noise(p) / 12.0; p = m * p * 1.4;
    f += noise(p) / 24.0;
    return f;
}

vec3 filmic_aces(vec3 v)
{
    v = v * mat3(
        0.59719f, 0.35458f, 0.04823f,
        0.07600f, 0.90834f, 0.01566f,
        0.02840f, 0.13383f, 0.83777f
    );
    return (v * (v + 0.0245786f) - 9.0537e-5f) /
        (v * (0.983729f * v + 0.4329510f) + 0.238081f) * mat3(
        1.60475f, -0.53108f, -0.07367f,
        -0.10208f,  1.10813f, -0.00605f,
        -0.00327f, -0.07276f,  1.07602f
    );
}

vec3 sky(vec3 skypos, vec3 sunpos) {

    vec3 sunCol = sunDisk.xyz;
    vec3 baseSky = skyBase.xyz;
    vec3 topSky = skyTop.xyz;

    float sDist = dot(normalize(skypos), normalize(sunpos));

    vec3 npos = normalize(skypos);


    vec3 skyGradient = mix(baseSky, topSky, clamp(skypos.y * 2.0, 0.0, 0.7));

    vec3 final = skyGradient;
    final += sunHalo.xyz * clamp((sDist - 0.95) * 10.0, 0.0, 0.8) * 0.2;

    // Sun disk
    if(sDist > 0.9999) {
        final = sunDisk.xyz;
    }

    // Horizon halo
    final += mix(horizonHalo.xyz, vec3(0.0,0.0,0.0), clamp(abs(npos.y) * 80.0, 0.0, 1.0)) * 0.1;

    final = vec3(final);

    // Cirrus Clouds
    if(hasClouds == 1) {
        float density = smoothstep(1.0 - cirrus, 1.0, fbm(npos.xyz / npos.y * 2.0 + time * 0.05)) * 0.3;
        final.rgb = mix(final.rgb, vec3(1.0, 1.0, 1.0), max(0.0, npos.y) * density * 2.0);
    }

    return final;
}

// ---- PBR FUNCTIONS ----

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;
    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);
    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// ---- RDM FUNCTIONS ----

float roughness_to_rdm_size(int roughness) {
    return pow(2.0, float((7 - roughness) + 1));
}

int rdm_index_from_normal(vec3 N) {
    vec3 n_leftright = vec3(0.0, 0.0, 1.0);
    vec3 n_updown = vec3(0.0, 1.0, 0.0);
    vec3 n_frontback = vec3(1.0, 0.0, 0.0);

    int res = 0;
    res += int(dot(-n_updown, N) >= 0.98) * 1;
    res += int(dot(n_leftright, N) >= 0.98) * 2;
    res += int(dot(-n_leftright, N) >= 0.98) * 3;
    res += int(dot(n_frontback, N) >= 0.98) * 4;
    res += int(dot(-n_frontback, N) >= 0.98) * 5;

    return res;
}

// Taken from Cigolle2014Vector.pdf
vec2 rdm_get_hemioct(vec3 v, int index, vec2 off) {
    vec3 vc = v;
    if(index / 2 == 0) {
        vc.z = v.y;
        vc.y = v.z;
    }
    if(index / 2 == 2) {
        vc.z = v.x;
        vc.x = v.z;
    }
    if(index % 2 == 1) {
        vc.z *= -1.0;
    }

    vc.x += off.x;
    vc.y += off.y;

    normalize(vc);
    
    vec2 p = vc.xy * (1.0 / (abs(vc.x) + abs(vc.y) + vc.z));
    vec2 res = vec2(p.x + p.y, p.x - p.y);
    res.x = (res.x + 1.0) * 0.5;
    res.y = (res.y + 1.0) * 0.5;
    return res;
}

float rdm_offset_y(int index) {
    return float((index / 2)) * (1.0/3.0);
}

float rdm_offset_x(int index) {
    return float((index % 2)) * (1.0/2.0);
}

vec4 rdm_get_atlas_rect(ivec3 local_pos, int roughness) {
    int rdm_index = local_pos.x + local_pos.y * 32 + local_pos.z * 1024 + roughness * 32768;
    int tx = rdm_index % 512;
    int ty = rdm_index / 512;
    return texelFetch(sampler2D(rdm_lookup, trilesmp), ivec2(tx, ty), 0);
}

ivec2 rdm_face_pixel_offset(vec4 atlas_rect, int face, int rdmSize) {
    ivec2 atlasSize = textureSize(sampler2D(rdm_atlas, rdmsmp), 0);
    int col = face % 2;
    int row = face / 2;
    int ox = int(atlas_rect.x * float(atlasSize.x)) + col * rdmSize;
    int oy = int(atlas_rect.y * float(atlasSize.y)) + row * rdmSize;
    return ivec2(ox, oy);
}

vec3 sample_rdm(vec3 N, vec3 V, vec3 rdm_center, vec3 diff, int roughness, ivec3 local_pos) {
    int face = rdm_index_from_normal(N);
    vec4 atlas_rect = rdm_get_atlas_rect(local_pos, roughness);
    if (atlas_rect.z <= 0.0) return vec3(1.0, 0.0, 1.0); // No data - magenta

    ivec2 atlasTexSize = textureSize(sampler2D(rdm_atlas, rdmsmp), 0);
    int rdmSizeInt = int(atlas_rect.z * float(atlasTexSize.x)) / 2;
    float rdmSize = float(rdmSizeInt);

    ivec2 faceOffset = rdm_face_pixel_offset(atlas_rect, face, rdmSizeInt);

    vec2 uv;
    if (face == 0 || face == 1) {       // +Y / -Y
        uv = vec2(ipos.x, ipos.z);
    } else if (face == 2 || face == 3) { // +Z / -Z
        uv = vec2(ipos.x, ipos.y);
    } else {                             // +X / -X
        uv = vec2(ipos.z, ipos.y);
    }

    vec3 reflected = normalize(reflect(V, N));

    if (roughness > 1) {
        vec3 samplePos = normalize(diff + 2.0 * reflected);
        vec2 hemiUV = rdm_get_hemioct(samplePos, face, vec2(0.0));
        vec2 atlasSize = vec2(textureSize(sampler2D(rdm_atlas, rdmsmp), 0));
        vec2 texUV = (vec2(faceOffset) + hemiUV * rdmSize) / atlasSize;
        return texture(sampler2D(rdm_atlas, rdmsmp), texUV).rgb;
    }

    float maxDist = 20.0;
    int steps = 40;
    for (int i = 0; i < steps; i++) {
        float t = maxDist * float(i + 1) / float(steps);
        vec3 samplePos = diff + t * reflected;
        if (dot(samplePos, N) < 0.0) continue;

        vec2 hemiUV = rdm_get_hemioct(normalize(samplePos), face, vec2(0.0));
        vec2 atlasSize = vec2(textureSize(sampler2D(rdm_atlas, rdmsmp), 0));
        vec2 texCoord = (vec2(faceOffset) + hemiUV * rdmSize) / atlasSize;
        vec4 rdmSample = texture(sampler2D(rdm_atlas, rdmsmp), texCoord, 0);
        float depth = rdmSample.a;
        float dist = length(samplePos);
        float stepSize = maxDist / float(steps);

        if (depth > 0.0 && depth < dist && depth + stepSize > dist) {
            return rdmSample.rgb;
        }
    }

    vec3 skyDir = reflected;
    if (skyDir.y < 0.0) skyDir = reflect(skyDir, vec3(0.0, 1.0, 0.0));
    return sky(skyDir, sunPosition);
}

vec3 sample_rdm_diff_map(vec3 N, ivec3 local_pos, vec3 fallback) {
    vec4 atlas_rect = rdm_get_atlas_rect(local_pos, 7);
    if (atlas_rect.z <= 0.0) return fallback;

    int face = rdm_index_from_normal(N);
    int rdmSize = int(roughness_to_rdm_size(7));
    ivec2 faceOffset = rdm_face_pixel_offset(atlas_rect, face, rdmSize);
    vec2 pos = rdm_get_hemioct(N, face, vec2(0.0));
    ivec2 texCoord = ivec2(faceOffset.x + int(pos.x * float(rdmSize)),
                           faceOffset.y + int(pos.y * float(rdmSize)));
    return texelFetch(sampler2D(rdm_atlas, rdmsmp), texCoord, 0).rgb;
}

int isign(float f) {
    return f < 0.0 ? -1 : 1;
}

vec3 smix(vec3 a, vec3 b, float t) {
    float power = 1.6;
    float smoothT = pow(t, power) / (pow(t, power) + pow(1.0 - t, power));
    return mix(a, b, smoothT);
}

vec3 sample_rdm_diff(vec3 N, vec3 diff, ivec3 local_pos) {
    int face = rdm_index_from_normal(N);
    vec3 ambientPlaceholder = vec3(0.3, 0.3, 0.4);

    vec2 delta = vec2(0.0);
    if (face == 0 || face == 1) {
        delta = vec2(diff.x, diff.z);
    } else if (face == 2 || face == 3) {
        delta = vec2(diff.x, diff.y);
    } else {
        delta = vec2(diff.z, diff.y);
    }

    ivec3 s0 = ivec3(0, 0, 0);
    ivec3 s1, s2, s3;
    if (face == 0 || face == 1) {
        s1 = ivec3(isign(delta.x), 0, 0);
        s2 = ivec3(0, 0, isign(delta.y));
        s3 = ivec3(isign(delta.x), 0, isign(delta.y));
    } else if (face == 2 || face == 3) {
        s1 = ivec3(isign(delta.x), 0, 0);
        s2 = ivec3(0, isign(delta.y), 0);
        s3 = ivec3(isign(delta.x), isign(delta.y), 0);
    } else {
        s1 = ivec3(0, 0, isign(delta.x));
        s2 = ivec3(0, isign(delta.y), 0);
        s3 = ivec3(0, isign(delta.y), isign(delta.x));
    }

    vec3 p0 = sample_rdm_diff_map(N, ivec3(mod(vec3(local_pos + s0), 32.0)), ambientPlaceholder);
    vec3 p1 = sample_rdm_diff_map(N, ivec3(mod(vec3(local_pos + s1), 32.0)), ambientPlaceholder);
    vec3 p2 = sample_rdm_diff_map(N, ivec3(mod(vec3(local_pos + s2), 32.0)), ambientPlaceholder);
    vec3 p3 = sample_rdm_diff_map(N, ivec3(mod(vec3(local_pos + s3), 32.0)), ambientPlaceholder);

    return smix(
        smix(p0, p1, abs(delta.x)),
        smix(p2, p3, abs(delta.x)),
        abs(delta.y)
    );
}

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

void main() {
    if (vpos.y < planeHeight - 0.01 && is_reflection == 1) {
        discard;
    }

    // Trixel material sampling
    vec3 pos_after_adjust = ipos - orig_normal * 0.02;
    int count = 0;
    vec4 trixel_material;
    while (count < 5) {
        int xpos = int(clamp(pos_after_adjust.z, 0.0001, 0.99999) * 16.0);
        int ypos = int(clamp(pos_after_adjust.y, 0.0001, 0.99999) * 16.0);
        int zpos = int(clamp(pos_after_adjust.x, 0.0001, 0.99999) * 16.0);

        trixel_material = texelFetch(sampler2D(triletex, trilesmp), ivec2(xpos, ypos + zpos * 16), 0);
        if (length(trixel_material) > 0.01) break;
        pos_after_adjust += to_center * 0.1;
        count++;
    }

    vec3 albedo = trixel_material.xyz;
    int packedMaterial = int(round(trixel_material.w * 255.0));
    float emittance  = 0.0;
    int   roughnessInt = 0;
    float roughness  = 0.05;
    float metallic   = 0.0;
    if ((packedMaterial & 0x1) != 0) {
        emittance = float((packedMaterial >> 1) & 0x7F) / 127.0;
    } else {
        roughnessInt = (packedMaterial >> 5) & 0x7;
        roughness    = max(float(roughnessInt) / 7.0, 0.05);
        metallic     = float((packedMaterial >> 3) & 0x3) / 3.0;
    }

    // Snap normal to nearest axis to avoid interpolation noise
    vec3 absN = abs(fnormal.xyz);
    vec3 N;
    if (absN.x >= absN.y && absN.x >= absN.z) {
        N = vec3(sign(fnormal.x), 0.0, 0.0);
    } else if (absN.y >= absN.x && absN.y >= absN.z) {
        N = vec3(0.0, sign(fnormal.y), 0.0);
    } else {
        N = vec3(0.0, 0.0, sign(fnormal.z));
    }

    vec3 V = normalize(cam - vpos.xyz);
    vec3 L = normalize(sunPosition);
    vec3 H = normalize(V + L);

    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo, metallic);
    vec3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);
    float NDF = DistributionGGX(N, H, roughness);
    float G = GeometrySmith(N, V, L, roughness);
    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;
    float NdotL = max(dot(N, L), 0.0);
    vec3 kD = vec3(1.0) - F;
    kD *= 1.0 - metallic;

    // Shadow
    vec4 light_proj_pos = mvp_shadow * vec4(floor(vpos.xyz * 16.0) / 16.0, 1.0);
    vec3 light_pos = light_proj_pos.xyz / light_proj_pos.w;
    light_pos = light_pos * 0.5 + 0.5;
    light_pos.z -= 0.001;
    float shadowp = texture(sampler2DShadow(shadowtex, shadowsmp), light_pos);

    // Direct lighting
    vec3 light = shadowp * (kD * albedo / PI + specular) * NdotL * sunLightColor * sunIntensity;

    // RDM indirect lighting
    vec3 hemispherePos = trileCenter + N * 0.49;
    ivec3 local = ivec3(mod(floor(trileCenter), 32.0));
    vec4 atlas_rect_check = rdm_get_atlas_rect(local, roughnessInt);
    float ssao_sample = texture(sampler2D(ssaotex, trilesmp), vec2(gl_FragCoord.x / float(screen_w), gl_FragCoord.y / float(screen_h)), 0).r;

    // Emissive — self-lit, not shadowed.
    vec3 emissive = albedo * emittance * emissive_scale;

    if (rdm_enabled == 1 && atlas_rect_check.z > 0.0) {
        vec3 Frough = FresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);

        // Indirect specular
        vec3 indirectSpec = sample_rdm(N, -cv,
            hemispherePos, vpos - hemispherePos, roughnessInt, local) * rdm_tint;

        // For metallic surfaces: desaturate the reflection so Frough (which uses albedo
        // as F0 for metals) applies the metal tint cleanly without double-tinting.
        float specLum = dot(indirectSpec, vec3(0.2126, 0.7152, 0.0722));
        indirectSpec = mix(indirectSpec, vec3(specLum), metallic);

        vec2 envBRDF = texture(sampler2D(brdf_lut, rdmsmp), vec2(max(dot(N, V), 0.0), roughness)).rg;
        float NdotV_s = max(dot(N, V), 0.0);
        float roughnessBell = 1.0 - 0.7 * sin(roughness * PI);
        float grazingSuppress = 1.0 - 0.9 * roughness * sin(roughness * PI) * pow(1.0 - NdotV_s, 2.0);
        float specRoughFade = 1.0 - clamp((roughness - 0.5) / 0.3, 0.0, 1.0);
        light += indirectSpec * (Frough * envBRDF.x + envBRDF.y) * rdm_spec_scale * roughnessBell * grazingSuppress * specRoughFade;

        // Indirect diffuse (interpolated from neighbor probes)
        vec3 indirectDiff = sample_rdm_diff(N, vpos - hemispherePos, local) * rdm_tint;
        float diffLuma = dot(indirectDiff, vec3(0.2126, 0.7152, 0.0722));
        indirectDiff = mix(vec3(diffLuma), indirectDiff, rdm_diff_saturation);
        vec3 kDiff = 1.0 - Frough;
        kDiff *= 1.0 - metallic;
        light += (kDiff * indirectDiff / PI * albedo) * ssao_sample * rdm_diff_scale;
        if (rdm_diff_scale < 0.001) {
            light += ambient_color * ambient_intensity * albedo * ssao_sample;
        }
        if (length(light) < ambient_intensity) {
            light += ambient_color * (ambient_intensity - length(light)) * albedo * ssao_sample;
        }
    } else {
        // Fallback: ambient + sky reflection when no RDM data (or RDM disabled).
        light += ambient_color * ambient_intensity * albedo * ssao_sample;
        vec3 R = reflect(-V, N);
        if (R.y < 0.0) R = reflect(R, vec3(0.0, 1.0, 0.0));
        light += F * sky(R, sunPosition) * 0.1;
    }

    vec3 final_color = light + emissive;
    if (hsv_lighting == 1) {
        float albedo_lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722)) + 0.001;
        float light_lum  = dot(final_color, vec3(0.2126, 0.7152, 0.0722));
        vec3 hsv = rgb2hsv(albedo);
        hsv.z = clamp(hsv.z * (light_lum / albedo_lum), 0.0, 1.0);
        final_color = hsv2rgb(hsv);
    }
    frag_color = vec4(mix(deepColor, final_color, smoothstep(0.0, planeHeight, vpos.y)), 1.0);
    if (is_preview == 1) {
        frag_color.rgb = mix(frag_color.rgb, vec3(0.3, 0.7, 1.0), 0.5);
    } else if (is_preview == 2) {
        frag_color.rgb = mix(frag_color.rgb, vec3(1.0, 0.3, 0.2), 0.5);
    }
}
@end

@program trile vs_trile fs_trile
