const Position = struct { x: f32, y: f32 };

const game_state = struct {
    var player_position: Position = .{ .x = 7.0, .y = 5.0 };
};

export fn init() void {
    renderer.init();
}

var flash_character: bool = false;

export fn input(e: ?*const sapp.Event) void {
    if (e == null) return;
    const event = e.?;
    if (event.type == .KEY_DOWN) {
        switch (event.key_code) {
            .G => flash_character = true,
            .ESCAPE => sapp.quit(),
            else => {},
        }
    } else if (event.type == .KEY_UP) {
        switch (event.key_code) {
            .G => flash_character = false,
            else => {},
        }
    }
}

export fn frame() void {
    renderer.beginFrame();
    defer renderer.endFrame();

    renderer.renderLevel(&level.level);
    // character starts at 368 (0->22), 240 (0->14)
    if (flash_character) {
        renderer.drawTileTinted(.character, game_state.player_position.x, game_state.player_position.y, 24, 15, .{ 1.0, 1.0, 1.0, 1.0 });
    } else {
        renderer.drawTile(.character, game_state.player_position.x, game_state.player_position.y, 24, 15);
    }
    renderer.drawTileTinted(.character, game_state.player_position.x + 2.0, game_state.player_position.y, 24, 9, .{ 1.0, 0.0, 1.0, 0.1 });
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
