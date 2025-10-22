const state = struct {
    const display = struct {
        var pip: sg.Pipeline = .{};
        var bind: sg.Bindings = .{};
        var pass_action: sg.PassAction = .{};
    };
};

const DisplayVertex = struct {
    pos: [2]f32,
    uv: [2]f32,
};

const logical_width = 256.0;
const logical_height = 196.0;

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // Steps:
    // Render to an offscreen view and then display it

    const display_vertices = [_]DisplayVertex{
        .{ .pos = .{ 0.0, logical_height }, .uv = .{ 0.0, 1.0 } }, // bottom-left
        .{ .pos = .{ 0.0, 0.0 }, .uv = .{ 0.0, 0.0 } }, // top-left
        .{ .pos = .{ logical_width, logical_height }, .uv = .{ 1.0, 1.0 } }, // bottom-right
        .{ .pos = .{ logical_width, 0.0 }, .uv = .{ 1.0, 0.0 } }, // top-right
    };
    const display_indices = [_]u16{ 0, 1, 2, 1, 3, 2 };
    state.display.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&display_vertices),
        .usage = .{ .vertex_buffer = true },
    });
    state.display.bind.index_buffer = sg.makeBuffer(.{
        .data = sg.asRange(&display_indices),
        .usage = .{ .index_buffer = true },
    });

    // Probably shouldn't be an arena allocator.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    zstbi.init(allocator);

    var tilemap = zstbi.Image.loadFromFile("src/assets/tilemap.png", 4) catch unreachable;
    std.debug.print("{}px by {}px\n{} by {} tiles\n", .{
        tilemap.width,
        tilemap.height,
        tilemap.width / 16,
        tilemap.height / 16,
    });
    defer tilemap.deinit();
    var tilemap_image_data: sg.ImageData = .{};
    tilemap_image_data.mip_levels[0] = sg.asRange(tilemap.data);
    const tilemap_image: sg.Image = sg.makeImage(.{
        .width = @as(i32, @intCast(tilemap.width)),
        .height = @as(i32, @intCast(tilemap.height)),
        .data = tilemap_image_data,
    });

    state.display.bind.views[0] = sg.makeView(.{
        .texture = .{ .image = tilemap_image },
    });
    state.display.bind.samplers[0] = sg.makeSampler(.{
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        .wrap_u = .REPEAT,
        .wrap_v = .REPEAT,
    });

    state.display.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.25, .g = 0.5, .b = 0.75 },
    };

    state.display.pip = sg.makePipeline(.{
        .shader = sg.makeShader(display_shader.displayShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[display_shader.ATTR_display_position] = .{ .format = .FLOAT2, .offset = @offsetOf(DisplayVertex, "pos") };
            l.attrs[display_shader.ATTR_display_texcoord] = .{ .format = .FLOAT2, .offset = @offsetOf(DisplayVertex, "uv") };
            break :init l;
        },
        .index_type = .UINT16,
        .cull_mode = .NONE,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        },
    });
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

    sg.beginPass(.{
        .action = state.display.pass_action,
        .swapchain = sglue.swapchain(),
    });

    sg.applyPipeline(state.display.pip);
    sg.applyBindings(state.display.bind);
    const mvp: Mat4 = .ortho(0.0, logical_width, logical_height, 0.0, -1.0, 1.0);
    sg.applyUniforms(display_shader.UB_vs_params, sg.asRange(&mvp));
    sg.draw(0, 6, 1);
    sg.endPass();

    sg.commit();
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
const math = @import("math.zig");
const Mat4 = math.Mat4;
