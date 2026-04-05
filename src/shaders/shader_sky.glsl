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
    float skyIntensity;

    int hasClouds;

    float planeHeight;
    int animatePlaneHeight;
    vec3 waterColor;
    vec3 deepColor;

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

vec3 sky(vec3 skypos, vec3 sunpos) {

    vec3 sunCol = sunDisk.xyz;
    vec3 baseSky = skyBase.xyz;
    vec3 topSky = skyTop.xyz;

    float sDist = dot(normalize(skypos), normalize(sunpos));

    vec3 npos = normalize(skypos);


    vec3 skyGradient = mix(baseSky, topSky, clamp(skypos.y * 2.0, 0.0, 0.7));

    // Sun local frame — used for both halo and disk
    vec3 sunDir   = normalize(sunpos);
    vec3 sunRight = normalize(cross(sunDir, vec3(0.0, 1.0, 0.0)));
    vec3 sunUp    = normalize(cross(sunRight, sunDir));
    vec3 sd       = normalize(skypos) - sunDir * sDist;
    float dx      = dot(sd, sunRight);
    float dy      = dot(sd, sunUp);
    float squareDist = max(abs(dx), abs(dy));

    vec3 final = skyGradient;

    // Sun halo (square, smooth falloff)
    float haloFactor = clamp((0.25 - squareDist) * 6.0, 0.0, 1.0);
    final += sunHalo.xyz * haloFactor * haloFactor;

    // Sun square
    if(squareDist < 0.032) {
        final = sunDisk.xyz * 3.0;
    }

    // Horizon halo
    final += mix(horizonHalo.xyz, vec3(0.0,0.0,0.0), clamp(abs(npos.y) * 20.0, 0.0, 1.0)) * 0.8;

    final = vec3(final);
    return final;
}

// --- END SKY ----

void main() {
    vec3 dir = normalize(pos.xyz);
    vec3 color = skyIntensity * sky(dir, sunPosition);
    frag_color = vec4(color, 1.0);
}
@end

@program sky vs_sky fs_sky
