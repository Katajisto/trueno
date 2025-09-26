@vs vs_plane


in vec4 position;

layout(binding=0) uniform plane_vs_params {
    mat4 mvp;
};

out vec4 pos;
out flat int idx;


void main() {
    vec3 multisize = vec3(position.xyz * 1000.0);
    gl_Position = mvp * (vec4(multisize.x, 0.0 + float(gl_InstanceIndex) * 0.003, multisize.z, 1.0));
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

#define hash(p)  fract(sin(dot(p, vec2(11.9898, 78.233))) * 43758.5453)

float B(vec2 U) {          
    float v =  hash( U + vec2(-1, 0) )
             + hash( U + vec2( 1, 0) )
             + hash( U + vec2( 0, 1) )
             + hash( U + vec2( 0,-1) ); 
    return  hash(U) - v/4.  + .5;
}

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

void main() {
    
    if(planeType == 1) {
        frag_color = vec4(0.0, 0.0, 1.0, 1.0);
    } else {
        float density = 80000.0;
        vec2 densifiedCoordinate = pos.xz * density;
        densifiedCoordinate.x += sin(densifiedCoordinate.y);
        densifiedCoordinate.y += sin(densifiedCoordinate.x);
        vec2 ruohokeskus = round(densifiedCoordinate);
        
        float noiseval_fine = noise(densifiedCoordinate / 50.0);
        float noiseval_coarse = noise(densifiedCoordinate / 500.0);

        float h = (1.0 / 128.0) * idx;
        float rand = (B(ruohokeskus) + sin(pos.x) * 0.4) * 0.5;
        rand += noiseval_coarse * 0.4 + noiseval_fine * 0.1;

        ruohokeskus.x += sin(time * 1.2) * 0.6 * h;
        
        float distanceFromCenter = length(ruohokeskus - (densifiedCoordinate));
        
        
        if(idx > 0 && rand < 0.2) {
            discard;   
        }
        

        float thickness = 0.5;

        
         if(idx > 0 && (rand - h) * thickness < distanceFromCenter) {
             discard;   
         } else {
             frag_color = vec4(noiseval_coarse * 0.5, min(1.0, h + 0.2) + noiseval_fine * 0.2, 0.0, 1.0);
         }
        
        
        
    }
}
@end

@program plane vs_plane fs_plane
