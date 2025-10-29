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
layout(binding=0) uniform vs_params {
  vec2 screen_resolution;
};
layout(binding=0) uniform texture2D offscreen_texture;
layout(binding=0) uniform sampler sprite_sampler;

in vec2 v_texcoord;

out vec4 frag_color;

void main() {
    // Normalized -1 to +1, aspect ratio corrected
    vec2 clipPos = (gl_FragCoord.xy / screen_resolution - 0.5) 
                 * vec2(screen_resolution.x / screen_resolution.y, 1.0);

    float aberrationAmount = 0.03;
    vec2 offset = clipPos * clipPos * clipPos * aberrationAmount;

    vec4 colR = texture(sampler2D(offscreen_texture, sprite_sampler),
                        v_texcoord + offset);
    vec4 colG = texture(sampler2D(offscreen_texture, sprite_sampler),
                        v_texcoord);
    vec4 colB = texture(sampler2D(offscreen_texture, sprite_sampler),
                        v_texcoord - offset);

    frag_color = vec4(colR.r, colG.g, colB.b, colG.a);
}
@end

@program display vs fs
