@vs vs_plane

in vec4 position;

layout(binding=0) uniform plane_vs_params {
    mat4 mvp;
};

out vec4 pos;
out flat int idx;


void main() {
    vec3 multisize = vec3(position.xyz * 1000.0);
    gl_Position = mvp * (vec4(multisize.x, multisize.y + 0.1 + float(gl_InstanceIndex) * 0.005, multisize.z, 1.0));
    pos = position;
    idx = gl_InstanceIndex;
}
@end

@fs fs_plane

in vec4 pos;
in flat int idx;
out vec4 frag_color;

float random (vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,767.233)))* 43758.5453123);
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
        vec2 approxPos = vec2(int(pos.x * 50000.0), int(pos.z * 50000.0));
        float height = random(approxPos);
        if(height < float(idx) * 0.1) {
            discard;
        }
        frag_color = vec4(0.0, random(approxPos) + 0.1, 0.0, 1.0);
    }
}
@end

@program plane vs_plane fs_plane
