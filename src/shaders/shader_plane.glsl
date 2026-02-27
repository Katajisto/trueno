@vs vs_plane
// @glsl_options fixup_clipspace

in vec4 position;

layout(binding=0) uniform plane_vs_params {
    mat4 mvp;
    float planeHeight;
};

out vec4 pos;
out flat int idx;
out float depth;

void main() {
    vec3 multisize = vec3(position.xyz * 1000.0);
    multisize.y += float(gl_InstanceIndex) * planeHeight;
    gl_Position = mvp * vec4(multisize, 1.0);
    depth = gl_Position.z;
    pos = vec4(multisize, 1.0);
    idx = gl_InstanceIndex;
}
@end

@fs fs_plane

in vec4 pos;
in flat int idx;
in float depth;
out vec4 frag_color;

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
    float planeHeight;
    int planeType;
    vec3 waterColor;
    vec3 deepColor;
    float time;
};

layout(binding=2) uniform plane_data {
    mat4 mvp_shadow;
    int screen_w;
    int screen_h;
    int is_reflection_pass;
    vec3 cameraPosition;
    float shininess; // Controls the size of the sun's glint, e.g., 64.0
    float reflectionDistortion; // Controls how much waves distort reflections, e.g., 0.05
};

// Texture bindings
layout(binding = 0) uniform texture2D reftex;
layout(binding = 1) uniform texture2D shadow;
layout(binding = 2) uniform texture2D normal_map;

// Sampler bindings
layout(binding = 0) uniform sampler refsmp;
layout(binding = 1) uniform sampler plane_shadowsmp;
layout(binding = 2) uniform sampler normalsmp;

vec3 fresnelSchlick(float cosTheta) {
    vec3 F0 = vec3(0.02);
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), 
                   hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), 
                   hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0; // Double the frequency
        amplitude *= 0.5; // Halve the amplitude
    }
    return value;
}

vec3 sky(vec3 skypos, vec3 sunpos) {
    vec3 skyGradient = mix(skyBase, skyTop, clamp(skypos.y * 2.0, 0.0, 0.7));
    vec3 final = skyGradient;
    return final;
}

void main() {
    if(idx == 1) { // Second instance of the plane is the actual water surface.
        vec2 uv1 = pos.xz * 0.4 + time * vec2(-0.005, -0.012) * 1.5;
        vec2 uv2 = pos.xz * 0.1 + time * vec2(-0.005, -0.012) * 1.7;
        vec2 uv3 = pos.xz * 1.0 + time * vec2(-0.005, -0.012) * 2.7;
        vec2 uv4 = pos.xz * 0.02 + time * vec2(-0.005, -0.012) * 0.1;

        vec3 normal1 = texture(sampler2D(normal_map, normalsmp), uv1).xzy * 2.0 - 1.0;
        vec3 normal2 = texture(sampler2D(normal_map, normalsmp), uv2).xzy * 2.0 - 1.0;
        vec3 normal3 = texture(sampler2D(normal_map, normalsmp), uv3).xzy * 2.0 - 1.0;
        vec3 normal4 = texture(sampler2D(normal_map, normalsmp), uv4).xzy * 2.0 - 1.0;

        vec3 normal = normalize(normal1 + normal2 + normal3 + normal4);

        vec3 view_dir = normalize(cameraPosition - pos.xyz);
        vec3 light_dir = normalize(sunPosition);
        vec3 halfway_dir = normalize(light_dir + view_dir);

        float diffuse = max(0.0, dot(normal, light_dir));
        float spec = pow(max(0.0, dot(halfway_dir, normal)), 32);
        float fresnel = min(1.0, fresnelSchlick(dot(view_dir, vec3(0.0, 1.0, 0.0))).x + 0.3);

        vec4 shadow_proj_pos = mvp_shadow * vec4(pos.xyz, 1.0);
        vec3 shadow_pos = shadow_proj_pos.xyz / shadow_proj_pos.w;
        shadow_pos = shadow_pos * 0.5 + 0.5;
        shadow_pos.z -= 0.001;
        float shadowp = texture(sampler2DShadow(shadow, plane_shadowsmp), shadow_pos);

        vec3 refracted_color = waterColor * diffuse * sunLightColor * sunIntensity * shadowp;
        vec3 specular_highlight = sunLightColor * sunIntensity * spec * shadowp;

        vec2 screen_uv = gl_FragCoord.xy / vec2(screen_w, screen_h);
        screen_uv.y = 1.0 - screen_uv.y;
        vec2 distortion = normal.xz * 0.005;
        vec3 reflected_color = texture(sampler2D(reftex, refsmp), screen_uv + distortion).rgb;

        vec3 surface_color = mix(refracted_color, reflected_color, fresnel);
        vec3 final_color = surface_color + specular_highlight;
        float alpha = mix(0.3, 0.5, fresnel);

        vec3 fog = skyIntensity * sky(normalize(pos.xyz), sunPosition);
        float fogFactor = smoothstep(750.0, 1000.0, length(pos.xz));

        frag_color = vec4(mix(final_color, fog, fogFactor), mix(alpha, 1.0, fogFactor));

    } else { // Deep water plane
        vec2 noise_uv = pos.xz * 0.05 + time * 0.01;
        float noise_value = fbm(noise_uv);
        vec3 noisy_deep_color = deepColor * mix(0.8, 1.2, noise_value);
        frag_color = vec4(noisy_deep_color, 1.0);
    }
}
@end

@program plane vs_plane fs_plane
