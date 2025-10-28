@header const m = @import("../math.zig")
@ctype mat4 m.mat4

@vs vs
in vec2 position;
in vec2 texcoord;

out vec2 v_texcoord;

void main() {
  gl_Position = vec4(position, 0.0, 1.0);
  v_texcoord = texcoord;
}
@end

@fs fs
precision mediump float;

layout(binding=0) uniform vs_params {
  float u_time;
};
layout(binding=0) uniform texture2D offscreen_texture;
layout(binding=0) uniform sampler sprite_sampler;

in vec2 v_texcoord;

out vec4 frag_color;

vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb2hsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void main() {
  vec4 color = texture(sampler2D(offscreen_texture, sprite_sampler), v_texcoord);
  vec3 hsv = rgb2hsv(color.rgb);
  hsv.x = fract(hsv.x + u_time);
  vec3 shifted_color = hsv2rgb(hsv);

  frag_color = vec4(shifted_color, color.a);
}
@end

@program display vs fs
