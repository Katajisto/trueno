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
in vec3 cv;
out vec4 frag_color;

layout(binding=3) uniform trile_fs_params {
    mat4  mvp_shadow;
    int   is_reflection;
    int   screen_h;
    int   screen_w;
    float ambient_intensity;
    float emissive_scale;
    float indirect_diff_scale;
    float indirect_spec_scale;
    vec3  ambient_color;
    int   is_preview;
    vec3  indirect_tint;
    int   sh_enabled;
    float fog_start;
    float fog_end;
};

layout(binding = 0) uniform texture2D triletex;
layout(binding = 0) uniform sampler trilesmp;
layout(binding = 1) uniform texture2D ssaotex;
layout(binding = 2) uniform texture2D shadowtex;
layout(binding = 2) uniform sampler shadowsmp;
layout(binding = 3) uniform texture2D brdf_lut;
layout(binding = 4) uniform texture2D sh_irradiance;
layout(binding = 3) uniform sampler linsmp;

const float PI = 3.1415927;
const float ROUGHNESS_SPEC_CUTOFF = 0.7;

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

void main() {
    if (vpos.y < planeHeight - 0.01 && is_reflection == 1) discard;

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

    vec3 absN = abs(fnormal.xyz);
    vec3 N;
    if      (absN.x >= absN.y && absN.x >= absN.z) N = vec3(sign(fnormal.x), 0.0, 0.0);
    else if (absN.y >= absN.x && absN.y >= absN.z) N = vec3(0.0, sign(fnormal.y), 0.0);
    else                                            N = vec3(0.0, 0.0, sign(fnormal.z));

    if (is_reflection == 1) {
        vec3 L = normalize(sunPosition);
        float NdotL = max(dot(N, L), 0.0);
        frag_color = vec4(albedo * (NdotL * sunLightColor * sunIntensity + 0.1), 1.0);
        return;
    }

    vec3 V = normalize(cam - vpos);
    vec3 L = normalize(sunPosition);
    vec3 H = normalize(V + L);
    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    vec3 F0 = mix(vec3(0.04), albedo, metallic);
    vec3 F  = fresnelSchlick(HdotV, F0);
    float NDF = DistributionGGX(N, H, roughness);
    float G   = GeometrySmith(N, V, L, roughness);
    vec3 kD   = (1.0 - F) * (1.0 - metallic);

    vec4 light_proj = mvp_shadow * vec4(floor(vpos * 16.0) / 16.0, 1.0);
    vec3 light_ndc  = light_proj.xyz / light_proj.w * 0.5 + 0.5;
    light_ndc.z -= 0.001;
    float shadow = texture(sampler2DShadow(shadowtex, shadowsmp), light_ndc);

    vec3 direct_specular = (NDF * G * F) / (4.0 * NdotV * NdotL + 0.0001);
    vec3 light = shadow * (kD * albedo / PI + direct_specular) * NdotL * sunLightColor * sunIntensity;

    float ssao    = texture(sampler2D(ssaotex, linsmp),
                            gl_FragCoord.xy / vec2(float(screen_w), float(screen_h))).r;
    vec3 emissive = albedo * emittance * emissive_scale;

    vec3 Frough = FresnelSchlickRoughness(NdotV, F0, roughness);

    if (roughness < ROUGHNESS_SPEC_CUTOFF) {
        vec3  R           = reflect(-V, N);
        vec2  envBRDF     = texture(sampler2D(brdf_lut, linsmp), vec2(NdotV, roughness)).rg;
        float specRoughFd = 1.0 - clamp((roughness - 0.5) / 0.3, 0.0, 1.0);
        light += sky_reflect(R, sunPosition) * (Frough * envBRDF.x + envBRDF.y)
               * indirect_spec_scale * specRoughFd;
    }

    vec3 indirectDiff;
    if (sh_enabled == 1) {
        vec2 sh_uv   = gl_FragCoord.xy / vec2(float(screen_w), float(screen_h));
        indirectDiff = texture(sampler2D(sh_irradiance, linsmp), sh_uv).rgb * indirect_tint;
    } else {
        indirectDiff = ambient_color * ambient_intensity;
    }

    light += (1.0 - Frough) * (1.0 - metallic) * indirectDiff / PI * albedo * ssao * indirect_diff_scale;

    vec3 final_color = light + emissive;
    final_color = mix(deepColor, final_color, smoothstep(0.0, planeHeight, vpos.y));

    float fog_dist   = length(vpos - cam);
    float fog_factor = smoothstep(fog_start, fog_end, fog_dist);
    final_color      = mix(final_color, skyBase, fog_factor);

    frag_color = vec4(final_color, 1.0);

    if      (is_preview == 1) frag_color.rgb = mix(frag_color.rgb, vec3(0.3, 0.7, 1.0), 0.5);
    else if (is_preview == 2) frag_color.rgb = mix(frag_color.rgb, vec3(1.0, 0.3, 0.2), 0.5);
}
@end

@program trile vs_trile fs_trile
