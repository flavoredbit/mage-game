@header const m = @import("../math.zig")
@ctype mat4 m.mat4

@vs vs
layout(binding=0) uniform vs_params {
  mat4 mvp;
};

in vec2 position;
in vec2 texcoord;
in int texidx;

out vec2 v_texcoord;
flat out int v_texidx;

void main() {
  gl_Position = mvp * vec4(position, 0.0, 1.0);
  v_texcoord = texcoord;
  v_texidx = texidx;
}
@end

@fs fs
layout(binding=0) uniform texture2D tilemap_texture;
layout(binding=1) uniform texture2D character_texture;
layout(binding=2) uniform texture2D interface_texture;
layout(binding=0) uniform sampler sprite_sampler;

in vec2 v_texcoord;
flat in int v_texidx;

out vec4 frag_color;

void main() {
  vec4 color;
  switch(v_texidx) {
    case 0: color = texture(sampler2D(tilemap_texture, sprite_sampler), v_texcoord); break;
    case 1: color = texture(sampler2D(character_texture, sprite_sampler), v_texcoord); break;
    case 2: color = texture(sampler2D(interface_texture, sprite_sampler), v_texcoord); break;
    default: color = vec4(1.0, 1.0, 1.0, 1.0);
  }
  frag_color = color;
}
@end

@program sprites vs fs
