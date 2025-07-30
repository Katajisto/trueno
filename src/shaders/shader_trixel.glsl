@vs vs_trixel

in vec4 position;
in vec4 normal;
in vec4 inst;
in vec4 inst_col;

layout(binding=0) uniform vs_params {
    mat4 mvp;
    vec3 camera;
};

out vec4 color;
out vec4 fnormal;
out vec4 pos;
out vec3 cam;

void main() {
    vec3 instancepos = inst.xyz;
    gl_Position = mvp * (vec4(position.xyz + instancepos, 1.0));
    fnormal = normal;
    color = inst_col;
    pos = gl_Position;
    cam = camera;
}
@end

@fs fs_trixel

layout(binding=1) uniform trixel_world_config {
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

    int hasPlane;
    float planeHeight;
    int planeType;

    float time;
};

in vec4 color;
in vec4 fnormal;
in vec4 pos;
in vec3 cam;
out vec4 frag_color;

const float PI = 3.1412854;


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
    // Get the material info.
    vec3 albedo = color.xyz;
    int packedMaterial = int(round(color.w*255.0));
    float emittance = float((packedMaterial >> 1) & 0x3) / 3.0;
    int roughnessInt = (packedMaterial >> 5) & 0x7;
    float roughness = max(float(roughnessInt) / 7.0, 0.05);
    float metallic = float((packedMaterial >> 3) & 0x3) / 3.0;
    
    // Ambient light.
    vec3 light = 0.3 * albedo;

    // // Make emitting things look bright.
    // if(emittance > 0.01) return vec4(albedo, 1.0);

    vec3 N = normalize(fnormal.xyz);
    vec3 V = normalize(cam - pos.xyz);
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

    light += (kD * albedo / PI + specular) * NdotL * vec3(1.0, 1.0, 1.0);

    frag_color = vec4(vec3(light), 1.0);
}
@end

@program trixel vs_trixel fs_trixel
