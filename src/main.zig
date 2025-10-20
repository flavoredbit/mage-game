const state = struct {
    var pass_action: sg.PassAction = .{};
};

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.25,  .g = 0.5, .b = 0.75 },
    };
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
    const dt: f32 = @floatCast(sapp.frameDuration() * 60);
    _ = dt;
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
