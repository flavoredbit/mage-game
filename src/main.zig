const Position = struct { x: f32, y: f32 };

const Action = enum { talk, shoot };
const Direction = enum { up, down, left, right };

const MoveTo = struct {
    start: Position,
    end: Position,
    progress: f32,
};

const Projectile = struct {
    position: Position,
    moving_to: MoveTo,
};

const Particle = struct {
    alive: bool,
    pos: Position,
    vel: Position,
    lifetime: f32,
    size: f32,
};

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;
var rand: std.Random = undefined;

const game_state = struct {
    var is_moving: bool = false;
    var is_firing: bool = false;
    var player_position: Position = .{ .x = 7.0, .y = 5.0 };
    var player_direction: Direction = .right;
    var projectile: ?Projectile = null;
    var npc_position: Position = .{ .x = 10.0, .y = 5.0 };
    var npc_is_dead: bool = false;
    var move_input: ?Direction = null;
    var action_input: ?Action = null;
    var moving_to: ?MoveTo = null;
    var tilemap: Tilemap = undefined;
    var particle_cooldown: f32 = 0.1;
    var particles: [100]Particle = std.mem.zeroes([100]Particle);
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
            .SPACE => game_state.action_input = .shoot,
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

fn playerFrame(direction: Direction) [2]u32 {
    return switch (direction) {
        .up => .{ 25, 6 },
        .down => .{ 24, 6 },
        .left => .{ 23, 6 },
        .right => .{ 26, 6 },
    };
}

fn difference(a: Position, b: Position) f32 {
    return @abs(a.x - b.x) + @abs(a.y - b.y);
}

export fn frame() void {
    rotation += std.math.pi / 32.0;

    if (!game_state.is_moving and !game_state.is_firing) {
        if (game_state.action_input) |action| {
            if (action == .shoot) {
                var projectile_moving_to: MoveTo = .{
                    .start = game_state.player_position,
                    .end = game_state.player_position,
                    .progress = 0.0,
                };
                switch (game_state.player_direction) {
                    .up => {
                        projectile_moving_to.start.y -= 1.0;
                        projectile_moving_to.end.y -= 3.0;
                    },
                    .down => {
                        projectile_moving_to.start.y += 1.0;
                        projectile_moving_to.end.y += 3.0;
                    },
                    .left => {
                        projectile_moving_to.start.x -= 1.0;
                        projectile_moving_to.end.x -= 3.0;
                    },
                    .right => {
                        projectile_moving_to.start.x += 1.0;
                        projectile_moving_to.end.x += 3.0;
                    },
                }

                game_state.projectile = .{
                    .position = projectile_moving_to.start,
                    .moving_to = projectile_moving_to,
                };
                game_state.action_input = null;
                game_state.is_firing = true;
                std.debug.print("Start shooting {}\n", .{game_state.projectile.?.position});
            }
        } else if (game_state.move_input) |move| {
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
            game_state.player_direction = move;

            // Without @round 4.999999 will be converted to 4.
            if (game_state.tilemap.canMoveTo(@intFromFloat(@round(moving_to.end.x)), @intFromFloat(@round(moving_to.end.y)))) {
                game_state.is_moving = true;
                game_state.moving_to = moving_to;
            }
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
    } else if (game_state.is_firing or game_state.projectile != null) {
        var projectile_position: *Position = &game_state.projectile.?.position;
        var projectile_moving_to: *MoveTo = &game_state.projectile.?.moving_to;
        projectile_moving_to.progress += 0.05;
        projectile_position.x = lerp(
            projectile_moving_to.start.x,
            projectile_moving_to.end.x,
            @min(projectile_moving_to.progress, 1.0),
        );
        projectile_position.y = lerp(
            projectile_moving_to.start.y,
            projectile_moving_to.end.y,
            @mod(projectile_moving_to.progress, 1.0),
        );

        std.debug.print("Test collision with {}, {}\n", .{
            @as(i32, @intFromFloat(@round(projectile_position.x))),
            @as(i32, @intFromFloat(@round(projectile_position.y))),
        });
        const npc_distance = difference(projectile_position.*, game_state.npc_position);
        if (npc_distance < 0.25) {
            game_state.npc_is_dead = true;
            game_state.is_firing = false;
            game_state.projectile = null;
        }
        if (projectile_moving_to.progress >= 1.0) {
            game_state.is_firing = false;
            game_state.projectile = null;
        }
    }

    renderer.beginFrame();
    defer renderer.endFrame(blur_screen);

    renderer.renderTilemap(&game_state.tilemap);
    // character starts at 368 (0->22), 240 (0->14)
    var player_frame = playerFrame(game_state.player_direction);
    if (game_state.is_moving) {
        if (game_state.moving_to.?.progress < 0.34) {
            player_frame[1] += 1;
        } else if (game_state.moving_to.?.progress > 0.67) {
            player_frame[1] += 2;
        }
    }
    if (flash_character) {
        renderer.drawTileTinted(
            .character,
            game_state.player_position.x,
            game_state.player_position.y,
            player_frame[0],
            player_frame[1],
            .{ 1.0, 1.0, 1.0, 1.0 },
        );
    } else {
        renderer.drawTile(
            .character,
            game_state.player_position.x,
            game_state.player_position.y,
            player_frame[0],
            player_frame[1],
        );
    }

    if (game_state.npc_is_dead) {
        const dt = @as(f32, @floatCast(sapp.frameDuration()));
        game_state.particle_cooldown -= dt;

        if (game_state.particle_cooldown <= 0.0) {
            game_state.particle_cooldown = 0.1;

            var first_dead_index: usize = 0;
            for (&game_state.particles, 0..) |*particle, i| {
                if (!particle.alive) {
                    first_dead_index = i;
                    break;
                }
            }

            const new_particle_count: usize = rand.intRangeAtMost(usize, 2, 5);
            for (0..new_particle_count) |i| {
                if (first_dead_index + i > 99) break;

                const blood_direction: f32 = (rand.float(f32) - 0.5) * 2.0;
                const blood_size = (rand.float(f32) * 2.0) + 1.0;
                const blood_offset_x = (rand.float(f32) - 0.5) * 0.25;
                const blood_offset_y = (rand.float(f32) - 0.5) * 0.25;
                game_state.particles[first_dead_index + i] = .{
                    .alive = true,
                    .lifetime = 2.0,
                    .pos = .{
                        .x = game_state.npc_position.x + 0.5 + blood_offset_x,
                        .y = game_state.npc_position.y + 0.5 + blood_offset_y,
                    },
                    .vel = .{ .x = blood_direction, .y = -3.0 },
                    .size = blood_size,
                };
            }
        }

        renderer.drawTileTinted(
            .character,
            game_state.npc_position.x,
            game_state.npc_position.y,
            24,
            15,
            .{ 1.0, 0.2, 0.1, 0.5 },
        );

        for (&game_state.particles) |*particle| {
            if (!particle.alive) continue;

            particle.vel.y -= -2.0 * dt;
            particle.pos.x += particle.vel.x * dt;
            particle.pos.y += particle.vel.y * dt;
            particle.lifetime -= dt;
            if (particle.lifetime < 0.0) {
                particle.alive = false;
                continue;
            } else {
                renderer.drawParticle(
                    particle.pos.x,
                    particle.pos.y,
                    particle.size,
                    .{ 1.0, 0.2, 0.1, 1.0 },
                );
            }
        }
    } else {
        renderer.drawTile(
            .character,
            game_state.npc_position.x,
            game_state.npc_position.y,
            24,
            15,
        );
    }

    renderer.drawTileRotated(
        .character,
        game_state.npc_position.x + 4.0,
        game_state.npc_position.y,
        24,
        9,
        rotation,
    );

    const npc_distance = difference(game_state.player_position, game_state.npc_position);
    if (npc_distance < 1.3) {
        renderer.drawTile(
            .interface,
            game_state.player_position.x,
            game_state.player_position.y - 0.75,
            5,
            3,
        );

        if (flash_character) {
            ui.drawDialog("Test", "Text goes here");
            const choices: [2][]const u8 = .{ "Yes", "No" };
            ui.drawChoice(&choices);
        }
    }

    if (game_state.projectile) |projectile| {
        const animation_progress: i32 = @intFromFloat(@round(projectile.moving_to.progress * 4.0));
        if (@rem(animation_progress, 2) == 0) {
            renderer.drawTile(.tilemap, projectile.position.x, projectile.position.y, 16, 10);
        } else {
            renderer.drawTileRotated(.tilemap, projectile.position.x, projectile.position.y, 16, 6, std.math.pi / 4.0);
        }
    }
}

export fn cleanup() void {
    sg.shutdown();
    arena.deinit();
}

pub fn main() !void {
    var seed: u64 = undefined;
    std.posix.getrandom(std.mem.asBytes(&seed)) catch |err| {
        std.debug.print("Failed to get random seed: {}\n", .{err});
        return;
    };

    var prng = std.Random.DefaultPrng.init(seed);
    rand = prng.random();

    const int_value = rand.intRangeAtMost(i32, 3, 10);
    std.debug.print("Random value: {}\n", .{int_value});

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    allocator = arena.allocator();

    game_state.tilemap = try .init(allocator, "Level_0");

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
const renderer = @import("renderer.zig");
const easing = @import("easing.zig");
const ui = @import("ui.zig");
const Tilemap = @import("tilemap.zig");
