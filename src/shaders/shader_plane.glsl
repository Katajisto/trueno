@vs vs_plane
// @glsl_options fixup_clipspace

in vec4 position;

layout(binding=0) uniform plane_vs_params {
    mat4 mvp;
};

out vec4 pos;
out flat int idx;

void main() {
    vec3 multisize = vec3(position.xyz * 1000.0);
    gl_Position = mvp * vec4(multisize, 1.0);
    pos = vec4(multisize, 1.0);
    idx = gl_InstanceIndex;
}
@end

@fs fs_plane

in vec4 pos;
in flat int idx;
out vec4 frag_color;

layout(binding=3) uniform plane_fs_params {
    mat4 mvp_shadow;
};

uint murmurHash12(uvec2 src) {
    const uint M = 0x5bd1e995u;
    uint h = 1190494759u;
    src *= M; src ^= src>>24u; src *= M;
    h *= M; h ^= src.x; h *= M; h ^= src.y;
    h ^= h>>13u; h *= M; h ^= h>>15u;
    return h;
}

float hash12(vec2 src) {
    uint h = murmurHash12(floatBitsToUint(src));
    return uintBitsToFloat(h & 0x007fffffu | 0x3f800000u) - 1.0;
}

layout(binding=1) uniform plane_world_config {
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

    float grassDensity;
};

layout(binding=2) uniform plane_data {
    int screen_w;
    int screen_h;
    int is_reflection_pass;
};

layout(binding = 0) uniform texture2D reftex;
layout(binding = 1) uniform texture2D groundtex;
layout(binding = 2) uniform texture2D shadow;
layout(binding = 0) uniform sampler refsmp;
layout(binding = 1) uniform sampler groundsmp;
layout(binding = 2) uniform sampler shadowsmp;

float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (vec2 st) {
    vec2 i = floor(st); // Integer part of the coordinate
    vec2 f = fract(st); // Fractional part of the coordinate

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    // Smoothstep for interpolation
    vec2 u = f*f*(3.0-2.0*f);

    // Mix (interpolate) the corners
    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

int sign2(float x) {
    if(x < 0) return -1;
    return 1;
}

vec3 get_ground_sample(vec4 pos, float dirX, float dirY) {
    ivec2 plane_coord = ivec2(floor(pos.x + dirX) + 500,  floor(pos.z + dirY) + 500);
    vec4 reflection   = texelFetch(sampler2D(reftex, refsmp), ivec2(gl_FragCoord.x, screen_h - gl_FragCoord.y), 0);
    vec4 groundSample = texelFetch(sampler2D(groundtex, groundsmp), plane_coord, 0);
    
    // Calculate all materials so we can blend them.
    vec3 water = reflection.xyz * vec3(0.95, 1.0, 0.95);
    vec3 sand  = vec3(mix(0.8, 1.0, hash12(pos.xz)) * vec3(0.8, 0.7, 0.5));
    vec3 grass = vec3(mix(0.8, 1.0, hash12(pos.xz)) * vec3(0.4, 0.8, 0.3));

    if(groundSample.b == 1.0) {
        return water;
    } else if(groundSample.r == 1.0) {
        return sand;
    } else {
        return grass;
    }
}

void main() {
    vec4 npos = floor(pos * 16.0) / 16.0;
    vec2 tileCenter = vec2(floor(npos.x) + 0.5, floor(npos.z) + 0.5);
    vec2 toCenter   = npos.xz - tileCenter;
    
    // Bilinear filtering
    float u = smoothstep(0.2, 0.5, abs(toCenter.x)) * 0.5;
    float v = smoothstep(0.2, 0.5, abs(toCenter.y)) * 0.5;
    
    // @ToDo: We should implement some sort of fog system and stop doing all this sampling
    // stuff if we are far enough from the camera. Currently ground rendering is taking way
    // too much time each frame.
    vec3 c0 = get_ground_sample(npos, 0.0, 0.0);
    vec3 c1 = get_ground_sample(npos, sign2(toCenter.x), 0.0);
    vec3 c2 = get_ground_sample(npos, 0.0, sign2(toCenter.y));
    vec3 c3 = get_ground_sample(npos, sign2(toCenter.x), sign2(toCenter.y));

    // @ToDo: Consider using cool Inigo Quilez trick here to make it even smoother.
    vec3 b01 = mix(c0, c1, u);
    vec3 b23 = mix(c2, c3, u);
    vec3 bf  = mix(b01, b23, v);
    
    vec4 light_proj_pos = mvp_shadow * vec4(npos.xyz + vec3(1.0/32.0, 0.0, 1.0/32.0), 1.0);
    vec3 light_pos = light_proj_pos.xyz / light_proj_pos.w;
    light_pos = light_pos * 0.5 + 0.5;
    float bias = 0.0005;
    float shadowp = max(0.7, texture(sampler2DShadow(shadow, shadowsmp), vec3(light_pos.xy, light_pos.z - bias)));
    
    if(planeType == 1) {
        frag_color = vec4(bf * shadowp, 1.0);
    } else {
        frag_color = vec4(vec3(shadowp), 1.0);
    }
}
@end

@program plane vs_plane fs_plane
