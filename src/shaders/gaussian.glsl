@vs vs
in vec2 position;
in vec2 texcoord;

out vec2 v_texcoord;

void main() {
  v_texcoord = texcoord;
  gl_Position = vec4(position, 0.0, 1.0);
}
@end

@fs fs
layout(binding=0) uniform vs_params {
  vec2 direction;
  vec2 resolution;
};
layout(binding=0) uniform texture2D to_blur_texture;
layout(binding=0) uniform sampler linear_sampler;

in vec2 v_texcoord;

out vec4 frag_color;

void main() {
  vec2 texel_size = 1.0 / resolution;
  vec3 result = vec3(0.0);

  float weights[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

  result += texture(sampler2D(to_blur_texture, linear_sampler), v_texcoord).rgb * weights[0];

  for (int i = 1; i < 5; i++) {
    vec2 offset = direction * texel_size * float(i);
    result += texture(sampler2D(to_blur_texture, linear_sampler), v_texcoord + offset).rgb * weights[i];
    result += texture(sampler2D(to_blur_texture, linear_sampler), v_texcoord - offset).rgb * weights[i];
  }

  frag_color = vec4(result, 1.0);
}
@end
@program gaussian vs fs
