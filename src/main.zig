const Position = struct { x: f32, y: f32 };

const Direction = enum { up, down, left, right };

const MoveTo = struct {
    start: Position,
    end: Position,
    progress: f32,
};

const game_state = struct {
    var is_moving: bool = false;
    var player_position: Position = .{ .x = 7.0, .y = 5.0 };
    var move_input: ?Direction = null;
    var moving_to: ?MoveTo = null;
};

export fn init() void {
    renderer.init();
}

// Copied from: https://github.com/Games-by-Mason/Tween/blob/main/src/interp.zig
// in case I need more.
fn lerp(start: f32, end: f32, t: f32) f32 {
    return @mulAdd(f32, start, 1.0 - t, end * t);
}

var flash_character: bool = false;
var blur_screen: bool = false;

export fn input(e: ?*const sapp.Event) void {
    if (e == null) return;
    const event = e.?;
    if (event.type == .KEY_DOWN) {
        switch (event.key_code) {
            .K => blur_screen = true,
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
            .K => blur_screen = false,
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

var rotation: f32 = 0.0;

export fn frame() void {
    rotation += std.math.pi / 32.0;

    if (!game_state.is_moving) {
        if (game_state.move_input) |move| {
            game_state.is_moving = true;
            game_state.moving_to = init: {
                var moving_to: MoveTo = .{
                    .start = game_state.player_position,
                    .end = game_state.player_position,
                    .progress = 0.0,
                };
                switch (move) {
                    .up => moving_to.end.y -= 1.0,
                    .down => moving_to.end.y += 1.0,
                    .left => moving_to.end.x -= 1.0,
                    .right => moving_to.end.x += 1.0,
                }
                break :init moving_to;
            };
        }
    }

    if (game_state.is_moving) {
        var moving_to: *MoveTo = &game_state.moving_to.?;
        moving_to.progress += 0.05;
        game_state.player_position.x = lerp(
            moving_to.start.x,
            moving_to.end.x,
            easing.smootherstep(moving_to.progress),
        );
        game_state.player_position.y = lerp(
            moving_to.start.y,
            moving_to.end.y,
            easing.smootherstep(moving_to.progress),
        );

        if (moving_to.progress >= 1.0) {
            game_state.is_moving = false;
            game_state.moving_to = null;
        }
    }

    renderer.beginFrame();
    defer renderer.endFrame(blur_screen);

    renderer.renderLevel(&level.level);
    // character starts at 368 (0->22), 240 (0->14)
    if (flash_character) {
        renderer.drawTileTinted(.character, game_state.player_position.x, game_state.player_position.y, 24, 15, .{ 1.0, 1.0, 1.0, 1.0 });
    } else {
        renderer.drawTile(.character, game_state.player_position.x, game_state.player_position.y, 24, 15);
    }
    renderer.drawTileTinted(.character, game_state.player_position.x + 2.0, game_state.player_position.y, 24, 9, .{ 1.0, 0.0, 1.0, 0.1 });

    renderer.drawTileRotated(
        .character,
        game_state.player_position.x + 4.0,
        game_state.player_position.y,
        24,
        9,
        rotation,
    );

    ui.drawDialog("Test", "Text goes here");
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
const easing = @import("easing.zig");
const ui = @import("ui.zig");
