@vs vs_plane


in vec4 position;

layout(binding=0) uniform plane_vs_params {
    mat4 mvp;
};

out vec4 pos;
out flat int idx;


void main() {
    vec3 multisize = vec3(position.xyz * 1000.0);
    gl_Position = mvp * (vec4(multisize.x, 0.0 + float(gl_InstanceIndex) * 0.006, multisize.z, 1.0));
    pos = vec4(multisize, 1.0);
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

    float grassDensity;
};

layout(binding=2) uniform plane_data {
    int screen_w;
    int screen_h;
    int is_reflection_pass;
};

layout(binding = 0) uniform texture2D reftex;
layout(binding = 2) uniform texture2D groundtex;
layout(binding = 0) uniform sampler refsmp;

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

vec3 wave(vec4 wave, vec3 p, inout vec3 tangent, inout vec3 binormal) {
    float steepness = wave.z;
    float wavelength = wave.w;
    float k = 2.0 * 3.141 / wavelength;
	float c = 2.0;
	vec2 d = normalize(vec2(wave.x, wave.y));
	float f = k * (dot(d, p.xz) - c * (time * 0.1));
	float a = steepness / k;
	
	tangent += vec3(
		-d.x * d.x * (steepness * sin(f)),
		d.x * (steepness * cos(f)),
		-d.x * d.y * (steepness * sin(f))
	);
    
	binormal += vec3(
		-d.x * d.y * (steepness * sin(f)),
		d.y * (steepness * cos(f)),
		-d.y * d.y * (steepness * sin(f))
	);
    
	return vec3(
		d.x * (a * cos(f)),
		a * sin(f),
		d.y * (a * cos(f))
	);
}

void main() {
    
    if(planeType == 1) {
        vec4 reflection = texelFetch(sampler2D(reftex, refsmp), ivec2(gl_FragCoord.x, screen_h - gl_FragCoord.y), 0);
        frag_color = reflection * vec4(0.9, 0.9, 1.0, 1.0);
    } else {
        float density = grassDensity;

        vec2 densifiedCoordinate = pos.xz * density;
        densifiedCoordinate.x += sin(densifiedCoordinate.y) * 0.5;
        densifiedCoordinate.y += sin(densifiedCoordinate.x) * 0.5;
        vec2 ruohokeskus = round(densifiedCoordinate);
        
        float noiseval_fine = noise(densifiedCoordinate / 50.0);
        float noiseval_coarse = noise(densifiedCoordinate / 500.0);
        float noiseval_plantti = noise(densifiedCoordinate / 500.0);       
        if(noiseval_plantti < 0.9) {
            noiseval_plantti = 0.0;
        } else {
            noiseval_plantti = (noiseval_plantti - 0.9) * 10.0;
        }

        float noiseval_vesi = noise(densifiedCoordinate.yx / 700.0);       
        int is_water = 0;
        float is_water_coast = 1.0;
        float coast_multiplier = 0.0;
        if(noiseval_vesi > 0.9) {
            is_water = 1;
            if(noiseval_vesi < 0.93) {
                is_water_coast = (noiseval_vesi - 0.9) * 33.333;
            }
        }
        if(noiseval_vesi > 0.8) {
            coast_multiplier = (noiseval_vesi - 0.8) * 10;
        }

        float rand = (hash12(ruohokeskus)) - 0.4;
        rand += 0.4 * noiseval_coarse;
        vec2 sandDensifiedCoordinate = round(pos.xz * density * 10.0);
        float sand_rand = (hash12(sandDensifiedCoordinate));
        vec4 sandcolor = vec4(mix(0.8, 1.0, sand_rand) * vec3(0.8, 0.7, 0.5), 1.0);
        if(is_water == 1) {
            vec3 tangent = vec3(1.0, 0.0, 0.0);
            vec3 binormal = vec3(0.0, 0.0, 1.0);
            vec3 p = vec3(0.0);
            p += wave(vec4(1.0, 0.5, 0.1, 0.9), pos.xyz, tangent, binormal);
            vec3 normal = normalize(cross(normalize(binormal), normalize(tangent)));

            vec2 rippleOffset = normal.xz * 0.005;
            rippleOffset.x = clamp(rippleOffset.x, -0.01, 0.01);
            rippleOffset.y = clamp(rippleOffset.y, -0.01, 0.01);
            vec3 light = normalize(sunPosition);
     
            float lightfactor = max(dot(light, normal),0.0);
            lightfactor = min(max(lightfactor, 0.1), 1.0);
            // float spec = max(dot(normalize(light + normalize(cv - fragWorldPos)), normal), 0.0);
            // spec -= 0.9;
            // spec = max(spec, 0.0);
            // spec *= 4.0;
            // vec3 specLight = spec * sunIntensity * sunColor.xyz;
            vec3 diffLight = lightfactor * sunIntensity * sunLightColor.xyz * 0.1;
            // vec3 totalLight = (specLight + diffLight);


            if(idx > 0 || is_reflection_pass == 1) discard;
            vec4 reflection = texelFetch(sampler2D(reftex, refsmp), ivec2(gl_FragCoord.x + int(rippleOffset.x * screen_w), screen_h + int(rippleOffset.y * screen_h) - gl_FragCoord.y), 0);
            frag_color = vec4(min(vec3(1.0), vec3(mix(1.0, 0.8, smoothstep(0.0, 0.9, is_water_coast))) + diffLight), 1.0) * mix(sandcolor, reflection, smoothstep(0.0, 0.9, is_water_coast));
            // frag_color = reflection;
        } else {
            float h = (1.0 / 128.0) * idx;

            
            rand -= mix(0.0, 1.0, coast_multiplier);
            rand = max(0.0, rand);

            ruohokeskus.x += sin(time * 1.2) * 0.2 * h;
        
            float distanceFromCenter = length(ruohokeskus - (densifiedCoordinate));
        
        
            if(idx > 0 && rand < 0.2) {
                discard;   
            }
        

            float thickness = 0.5;

        
             if(idx > 0 && (rand - h) * thickness < distanceFromCenter) {
                 discard;   
             } else {
                 if(idx == 0) {
                     frag_color = mix(vec4(noiseval_coarse * 0.5, 0.2 + noiseval_fine * 0.2, 0.1, 1.0),sandcolor,coast_multiplier);
                 } else {
                     vec4 grass_color = vec4(noiseval_coarse * 0.5, min(1.0, h + 0.2) + noiseval_fine * 0.2, 0.1, 1.0);
                     vec4 plantti_color = vec4(h, h * 0.3, 0.0, 1.0);
                     vec4 normal_ground_color = mix(grass_color, plantti_color, noiseval_plantti);
                     frag_color = mix(normal_ground_color, vec4(h * 2.0 + 0.4, h * 2.0 + 0.4, 0.0, 1.0), coast_multiplier);
                 }
             }
         }
    }
}
@end

@program plane vs_plane fs_plane
