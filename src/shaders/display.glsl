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
layout(binding=0) uniform texture2D offscreen_texture;
layout(binding=0) uniform sampler sprite_sampler;

in vec2 v_texcoord;

out vec4 frag_color;

void main() {
  frag_color = texture(sampler2D(offscreen_texture, sprite_sampler), v_texcoord);
}
@end

@program display vs fs
