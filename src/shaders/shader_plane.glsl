@vs vs_plane

in vec4 position;

layout(binding=0) uniform plane_vs_params {
    mat4 mvp;
};

out vec4 pos;
out flat int idx;


void main() {
    vec3 multisize = vec3(position.xyz * 1000.0);
    gl_Position = mvp * (vec4(multisize.x, 0.0 + float(gl_InstanceIndex) * 0.01, multisize.z, 1.0));
    pos = position;
    idx = gl_InstanceIndex;
}
@end

@fs fs_plane

in vec4 pos;
in flat int idx;
out vec4 frag_color;

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
};

void main() {
    
    if(planeType == 1) {
        frag_color = vec4(0.0, 0.0, 1.0, 1.0);
    } else {
        float density = 100000.0;
        vec2 uv = round(pos.xz * density);
        float distanceFromCenter = length(uv - (pos.xz * density));
        
        float rand = hash12(uv);
        float h = (1.0 / 16.0) * idx;

        float thickness = 0.5;
        
        if((rand - h) * thickness < distanceFromCenter) {
            discard;   
        }

        frag_color = vec4(0.0, rand, 0.0, 1.0);
    }
}
@end

@program plane vs_plane fs_plane
