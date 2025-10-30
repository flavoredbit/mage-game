const Position = struct { x: f32, y: f32 };

const game_state = struct {
    var player_position: Position = .{ .x = 7.0, .y = 5.0 };
};

export fn init() void {
    renderer.init();
}

export fn input(e: ?*const sapp.Event) void {
    if (e == null) return;
    const event = e.?;
    if (event.type == .KEY_DOWN) {
        switch (event.key_code) {
            .ESCAPE => sapp.quit(),
            else => {},
        }
    }
}

export fn frame() void {
    renderer.beginFrame();
    defer renderer.endFrame();

    renderer.renderLevel(&level.level);
    // character starts at 368 (0->22), 240 (0->14)
    renderer.drawTile(.character, game_state.player_position.x, game_state.player_position.y, 24, 15);
}

export fn cleanup() void {
    sg.shutdown();
}

pub fn main() !void {
    sapp.run(.{
        .init_cb = init,
        .event_cb = input,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 1024,
        .height = 768,
        .sample_count = 4,
        .icon = .{ .sokol_default = true },
        .window_title = "Mage Game",
        .logger = .{ .func = slog.func },
    });
}

const std = @import("std");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sglue = sokol.glue;
const slog = sokol.log;
const zstbi = @import("zstbi");
const display_shader = @import("shaders/display.zig");
const sprites_shader = @import("shaders/sprites.zig");
const math = @import("math.zig");
const Mat4 = math.Mat4;
const level = @import("level.zig");
const renderer = @import("renderer.zig");
