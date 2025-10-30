const Position = struct { x: f32, y: f32 };

const Direction = enum { up, down, left, right };

const game_state = struct {
    var is_moving: bool = false;
    var player_position: Position = .{ .x = 7.0, .y = 5.0 };
    var move_input: ?Direction = null;
    var position_diff: ?Position = null;
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
            .C => game_state.move_input = .up,
            .D => game_state.move_input = .down,
            .E => game_state.move_input = .left,
            .F => game_state.move_input = .right,
            .G => flash_character = true,
            .ESCAPE => sapp.quit(),
            else => {},
        }
    } else if (event.type == .KEY_UP) {
        switch (event.key_code) {
            .C => {
                if (game_state.move_input == .up) game_state.move_input = null;
            },
            .D => {
                if (game_state.move_input == .down) game_state.move_input = null;
            },
            .E => {
                if (game_state.move_input == .left) game_state.move_input = null;
            },
            .F => {
                if (game_state.move_input == .right) game_state.move_input = null;
            },
            .G => flash_character = false,
            else => {},
        }
    }
}

export fn frame() void {
    if (!game_state.is_moving) {
        if (game_state.move_input) |move| {
            game_state.is_moving = true;
            game_state.position_diff = switch (move) {
                .up => .{ .x = 0.0, .y = -1.0 },
                .down => .{ .x = 0.0, .y = 1.0 },
                .left => .{ .x = -1.0, .y = 0.0 },
                .right => .{ .x = 1.0, .y = 0.0 },
            };
        }
    }

    if (game_state.is_moving) {
        var position_diff: *Position = &game_state.position_diff.?;
        game_state.player_position.x += std.math.clamp(position_diff.x, -0.2, 0.2);
        game_state.player_position.y += std.math.clamp(position_diff.y, -0.2, 0.2);

        if (position_diff.x != 0.0) {
            position_diff.x -= std.math.copysign(@as(f32, 0.2), position_diff.x);
        }
        if (position_diff.y != 0.0) {
            position_diff.y -= std.math.copysign(@as(f32, 0.2), position_diff.y);
        }
        if (@abs(position_diff.x) < 0.1 and @abs(position_diff.y) < 0.1) {
            game_state.is_moving = false;
            game_state.position_diff = null;
        }
    }

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
