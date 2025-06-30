@vs vs_trixel

in vec4 position;
in vec4 normal;
in vec4 inst;
in vec4 inst_col;

layout(binding=0) uniform vs_params {
    mat4 mvp;
};


out vec4 color;
out vec4 fnormal;
out vec4 pos;

void main() {
    vec3 instancepos = inst.xyz;
    gl_Position = mvp * (vec4(position.xyz + instancepos, 1.0));
    fnormal = normal;
    color = inst_col;
    pos = gl_Position;
}
@end

@fs fs_trixel
in vec4 color;
in vec4 fnormal;
in vec4 pos;
out vec4 frag_color;


void main() {

    // 2 lights.
    vec3 light1 = vec3(5.0, 5.0, 2.0);
    vec3 light2 = vec3(-5.0, -2.0, -2.0);
    
    vec3 albedo = color.xyz;
    vec3 light = 0.3 * albedo;
    
    vec3 light1dir = normalize(light1 - pos.xyz);
    vec3 light2dir = normalize(light2 - pos.xyz);
    light +=  max(0.0, dot(light1dir, fnormal.xyz)) * albedo * 0.5;
    light +=  max(0.0, dot(light2dir, fnormal.xyz)) * albedo * 0.3 * vec3(1.0, 0.7, 0.7);
    frag_color = vec4(light, 1.0);
}
@end

@program trixel vs_trixel fs_trixel
