@vs vs_op
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.5, 1.0);
    texcoord = uv;
}
@end

@fs fs_op
in vec2 texcoord;
out vec4 frag_color;

layout(binding=1) uniform op_fs_params {
    /*
        List of ops:
        0. blur for ssao
        1. dilate.
        2. normal blur
        3. bloom
    */
    int op;

    // Common
    int blur_size;
    float separation;

    // DOF
    float dilate_min;
    float dilate_max;

    // Bloom
    float bloom_amount;
    float bloom_treshold;
    
};

layout(binding = 0) uniform texture2D optex;
layout(binding = 0) uniform sampler opsmp;

void main() {
    if(op == 3) {
        vec2 texSize = vec2(textureSize(sampler2D(optex, opsmp), 0));
        float value = 0.0;
        float count = 0.0;

        vec4 result = vec4(0.0);
        vec4 color  = vec4(0.0);

        for(int i = -blur_size ; i <= blur_size; ++i) {
            for(int j = -blur_size; j <= blur_size; ++j) {
                color = texture(sampler2D(optex, opsmp), (gl_FragCoord.xy + vec2(i,j) * separation) / texSize);
                value = max(color.r, max(color.g, color.b));
                if(value < bloom_treshold) { color = vec4(0); }
                result += color;
                count += 1.0;
            }
        }
        result /= count;
        frag_color = vec4(result.xyz * bloom_amount, 1.0);
    } else if(op == 2) {
        vec2 texelSize = 1.0 / vec2(textureSize(sampler2D(optex, opsmp), 0));
        vec3 result = vec3(0.0);
        for (int x = -blur_size; x < blur_size; ++x) 
        {
            for (int y = -blur_size; y < blur_size; ++y) 
            {
                vec2 offset = vec2(float(x), float(y)) * texelSize;
                result += texture(sampler2D(optex, opsmp), texcoord + offset).xyz;
            }
        }
        frag_color = vec4((result / (blur_size*2 * blur_size*2)), 1.0);
    }
    else if(op == 1) {
          float minThreshold = dilate_min;
          float maxThreshold = dilate_max;
          vec2 texSize   = textureSize(sampler2D(optex, opsmp), 0).xy;
          vec2 fragCoord = gl_FragCoord.xy;
          frag_color = texture(sampler2D(optex, opsmp), fragCoord / texSize);
          if (blur_size <= 0) { return; }
          float mx = 0.0;
          vec4 cmx = frag_color;
          for (int i = -blur_size; i <= blur_size; ++i) {
            for (int j = -blur_size; j <= blur_size; ++j) {
              if (!(distance(vec2(i, j), vec2(0, 0)) <= blur_size)) { continue; }
              vec4 c = texture(sampler2D(optex,opsmp),(gl_FragCoord.xy + (vec2(i, j) * separation)) / texSize);
              float mxt = dot(c.rgb, vec3(0.3, 0.59, 0.11));
              if (mxt > mx) {
                mx = mxt;
                cmx = c;
              }
            }
          }
          frag_color.rgb = mix(frag_color.rgb, cmx.rgb, smoothstep(minThreshold, maxThreshold, mx)); 
    } else {
        vec2 texelSize = 1.0 / vec2(textureSize(sampler2D(optex, opsmp), 0));
        float result = 0.0;
        for (int x = -blur_size; x < blur_size; ++x) {
            for (int y = -blur_size; y < blur_size; ++y) {
                vec2 offset = vec2(float(x), float(y)) * texelSize;
                result += texture(sampler2D(optex, opsmp), texcoord + offset).r;
            }
        }
        frag_color = vec4(vec3(result / (blur_size*2 * blur_size*2)), 1.0);
    }
}
@end

@program op vs_op fs_op
