@vs vs_trile

in vec4 position;
in vec4 normal;
in vec4 centre;
in vec4 instance;

layout(binding=0) uniform trile_vs_params {
    mat4 mvp;
    vec3 camera;
};

out vec3 cam;
out vec3 to_center;
out vec3 vpos;
out vec4 fnormal;

void main() {
    gl_Position = mvp * vec4(position.xyz + instance.xyz, 1.0);
    fnormal = normal;
    to_center = centre.xyz - position.xyz;
    vpos = position.xyz + instance.xyz;
    cam = camera;
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

    int hasClouds;

    int hasPlane;
    float planeHeight;
    int planeType;

    float time;
};

in vec3 cam;
in vec3 to_center;
in vec3 vpos;
in vec4 fnormal;
out vec4 frag_color;

layout(binding = 0) uniform texture2D triletex;
layout(binding = 0) uniform sampler trilesmp;

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

// ---- SKY END ----

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

void main() {
    //frag_color = vec4((fnormal.xyz + vec3(1.0, 1.0, 1.0)) * 0.5, 1.0);
    vec3 pos_after_adjust = vpos - fnormal.xyz * 0.02;
    int count = 0;
    vec4 trixel_material;
    while (count < 5) {
        int xpos = int(clamp(pos_after_adjust.z, 0.0001, 0.99999) * 16.0);
        int ypos = int(clamp(pos_after_adjust.y, 0.0001, 0.99999) * 16.0);
        int zpos = int(clamp(pos_after_adjust.x, 0.0001, 0.99999) * 16.0);

        trixel_material = texelFetch(sampler2D(triletex, trilesmp), ivec2(xpos, ypos + zpos * 16), 0);
        if (length(trixel_material) > 0.01) break; // @ToDo: Replace with proper null trixel check.
        pos_after_adjust += to_center * 0.1;
        count++;
    }
    
    vec3 albedo = trixel_material.xyz;
    int packedMaterial = int(round(trixel_material.w*255.0));
    float emittance = float((packedMaterial >> 1) & 0x3) / 3.0;
    int roughnessInt = (packedMaterial >> 5) & 0x7;
    float roughness = max(float(roughnessInt) / 7.0, 0.05);
    float metallic = float((packedMaterial >> 3) & 0x3) / 3.0;
    
    // Ambient light.
    vec3 light = 0.2 * albedo;

    vec3 N = normalize(fnormal.xyz);
    vec3 V = normalize(cam - vpos.xyz);
    vec3 L = normalize(sunPosition);
    vec3 H = normalize(V + L);

    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo, metallic);
    vec3 F = fresnelSchlick(max(dot(H,V), 0.0), F0);
    float NDF = DistributionGGX(N, H, roughness);
    float G = GeometrySmith(N, V, L, roughness);
    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0)  + 0.0001;
    vec3 specular = numerator / denominator;
    float NdotL = max(dot(N, L), 0.0);
    vec3 kD = vec3(1.0) - F;
    kD *= 1.0 - metallic;

    light += (kD * albedo / PI + specular) * NdotL * sunLightColor * sunIntensity;

    vec3 R = reflect(-V, N);
    vec3 modifier = vec3(1.0);
    if(R.y < 0.0) {
        R = reflect(R, vec3(0.0,1.0,0.0));
        modifier = vec3(0.7, 0.9, 0.7);
    }
    vec3 samp = sky(R, sunPosition);
    // light += F * samp * modifier;

    frag_color = vec4(vec3(light), 1.0);

}
@end

@program trile vs_trile fs_trile
