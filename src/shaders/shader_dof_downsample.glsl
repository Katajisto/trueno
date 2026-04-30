@vs vs_dof_downsample
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_dof_downsample
in vec2 texcoord;
out vec4 frag_color;

layout(binding = 0) uniform texture2D dof_downsample_src;
layout(binding = 0) uniform sampler dof_downsample_src_smp;

void main() {
    frag_color = vec4(texture(sampler2D(dof_downsample_src, dof_downsample_src_smp), texcoord).rgb, 1.0);
}
@end

@program dof_downsample vs_dof_downsample fs_dof_downsample
