@block view
layout(binding=0) uniform view_params {
    mat4 view_proj;
    vec4 camera;   // xyz = position, w = time
    vec4 clip;     // plane; geometry on its negative side is dropped
};
@end

@block quad
vec2 quad_corner(int vertex_index) {
    const vec2 corners[6] = vec2[6](vec2(0, 0), vec2(1, 0), vec2(1, 1), vec2(0, 0), vec2(1, 1), vec2(0, 1));
    return corners[vertex_index];
}
@end
