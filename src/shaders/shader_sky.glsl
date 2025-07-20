@vs vs_sky

in vec4 position;

layout(binding=0) uniform sky_vs_params {
    mat4 mvp;
};



out vec4 pos;

void main() {
    gl_Position = mvp * (vec4(position.xyz * 1000.0, 1.0));
    pos = position;
}
@end

@fs fs_sky
layout(binding=1) uniform sky_world_config {
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

in vec4 pos;
out vec4 frag_color;

const float cirrus = 0.5;
const float cumulus = 20.0;

// ----- SKY SHADER -------

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
    float density = smoothstep(1.0 - cirrus, 1.0, fbm(npos.xyz / npos.y * 2.0 + time * 0.05)) * 0.3;
    final.rgb = mix(final.rgb, vec3(1.0, 1.0, 1.0), max(0.0, npos.y) * density * 2.0);

    return final;
}

// --- END SKY ----

void main() {
    vec3 dir = normalize(pos.xyz);
    vec3 color = sky(dir, normalize(vec3(0.6,0.9,0.6)));
    frag_color = vec4(color, 1.0);
}
@end

@program sky vs_sky fs_sky
