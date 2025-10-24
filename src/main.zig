const render = struct {
    const sprites = struct {
        var attachments: sg.Attachments = .{};
        var color_tex_view: sg.View = .{};
        var pip: sg.Pipeline = .{};
        var bind: sg.Bindings = .{};
        var pass_action: sg.PassAction = .{};
    };
    const display = struct {
        var pip: sg.Pipeline = .{};
        var bind: sg.Bindings = .{};
        var pass_action: sg.PassAction = .{};
    };
};

const SpriteVertex = struct {
    pos: [2]f32,
    uv: [2]f32,
    tex_idx: u32,
};

const DisplayVertex = struct {
    pos: [2]f32,
    uv: [2]f32,
};

const tile_size = 16;
const logical_width = 256.0;
const logical_height = 196.0;
const max_sprites = 10_000;

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    render.sprites.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .size = @sizeOf(SpriteVertex) * max_sprites * 4,
        .usage = .{
            .vertex_buffer = true,
            .dynamic_update = true,
        },
    });
    var indices = std.mem.zeroes([max_sprites * 6]u16);
    for (0..max_sprites) |n| {
        const index_index = n * 6;
        const vertex_index: u16 = @intCast(n * 4);
        // Set the vertex index for each quad
        // 0, 1, 2
        // 1, 3, 2
        indices[index_index + 0] = vertex_index + 0;
        indices[index_index + 1] = vertex_index + 1;
        indices[index_index + 2] = vertex_index + 2;
        indices[index_index + 3] = vertex_index + 1;
        indices[index_index + 4] = vertex_index + 3;
        indices[index_index + 5] = vertex_index + 2;
    }
    render.sprites.bind.index_buffer = sg.makeBuffer(.{
        .data = sg.asRange(&indices),
        .usage = .{ .index_buffer = true },
    });

    // TODO: Make this a full screen normalized quad.
    const display_vertices = [_]DisplayVertex{
        .{ .pos = .{ 0.0, logical_height }, .uv = .{ 0.0, 1.0 } }, // bottom-left
        .{ .pos = .{ 0.0, 0.0 }, .uv = .{ 0.0, 0.0 } }, // top-left
        .{ .pos = .{ logical_width, logical_height }, .uv = .{ 1.0, 1.0 } }, // bottom-right
        .{ .pos = .{ logical_width, 0.0 }, .uv = .{ 1.0, 0.0 } }, // top-right
    };
    const display_indices = [_]u16{ 0, 1, 2, 1, 3, 2 };
    render.display.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&display_vertices),
        .usage = .{ .vertex_buffer = true },
    });
    render.display.bind.index_buffer = sg.makeBuffer(.{
        .data = sg.asRange(&display_indices),
        .usage = .{ .index_buffer = true },
    });

    // Probably shouldn't be an arena allocator.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    zstbi.init(allocator);

    var tilemap = zstbi.Image.loadFromFile("src/assets/tilemap.png", 4) catch unreachable;
    std.debug.print("Tilemap Tiles\n{}px by {}px\n{} by {} tiles\n\n", .{
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

    var characters = zstbi.Image.loadFromFile("src/assets/characters.png", 4) catch unreachable;
    std.debug.print("Characters Tiles\n{}px by {}px\n{} by {} tiles\n\n", .{
        characters.width,
        characters.height,
        characters.width / 16,
        characters.height / 16,
    });
    defer characters.deinit();
    var characters_image_data: sg.ImageData = .{};
    characters_image_data.mip_levels[0] = sg.asRange(characters.data);
    const characters_image: sg.Image = sg.makeImage(.{
        .width = @as(i32, @intCast(characters.width)),
        .height = @as(i32, @intCast(characters.height)),
        .data = characters_image_data,
    });

    var interface = zstbi.Image.loadFromFile("src/assets/interface.png", 4) catch unreachable;
    std.debug.print("Interface Tiles\n{}px by {}px\n{} by {} tiles\n\n", .{
        interface.width,
        interface.height,
        interface.width / 16,
        interface.height / 16,
    });
    defer interface.deinit();
    var interface_image_data: sg.ImageData = .{};
    interface_image_data.mip_levels[0] = sg.asRange(interface.data);
    const interface_image: sg.Image = sg.makeImage(.{
        .width = @as(i32, @intCast(interface.width)),
        .height = @as(i32, @intCast(interface.height)),
        .data = interface_image_data,
    });

    render.sprites.bind.views[0] = sg.makeView(.{
        .texture = .{ .image = tilemap_image },
    });
    render.sprites.bind.views[1] = sg.makeView(.{
        .texture = .{ .image = characters_image },
    });
    render.sprites.bind.views[2] = sg.makeView(.{
        .texture = .{ .image = interface_image },
    });
    render.sprites.bind.samplers[0] = sg.makeSampler(.{
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        .wrap_u = .CLAMP_TO_EDGE,
        .wrap_v = .CLAMP_TO_EDGE,
    });

    render.display.bind.samplers[0] = sg.makeSampler(.{
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        .wrap_u = .REPEAT,
        .wrap_v = .REPEAT,
    });

    var sprite_image_desc: sg.ImageDesc = .{
        .width = @intFromFloat(logical_width),
        .height = @intFromFloat(logical_height),
        .pixel_format = .RGBA8,
        .sample_count = 1,
        .usage = .{ .color_attachment = true },
    };
    const color_image = sg.makeImage(sprite_image_desc);
    sprite_image_desc.pixel_format = .DEPTH;
    sprite_image_desc.usage = .{ .depth_stencil_attachment = true };
    const depth_image = sg.makeImage(sprite_image_desc);

    const color_att_view = sg.makeView(.{
        .color_attachment = .{
            .image = color_image,
        },
    });
    const depth_att_view = sg.makeView(.{
        .depth_stencil_attachment = .{
            .image = depth_image,
        },
    });
    render.sprites.attachments = .{
        .colors = init: {
            var c: [8]sg.View = @splat(.{});
            c[0] = color_att_view;
            break :init c;
        },
        .depth_stencil = depth_att_view,
    };

    render.display.bind.views[0] = sg.makeView(.{
        .texture = .{
            .image = color_image,
        },
    });

    render.sprites.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 1.0, .g = 0.0, .b = 0.0 },
    };

    render.display.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.0, .b = 1.0 },
    };

    render.sprites.pip = sg.makePipeline(.{
        .shader = sg.makeShader(sprites_shader.spritesShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[sprites_shader.ATTR_sprites_position] = .{ .format = .FLOAT2, .offset = @offsetOf(SpriteVertex, "pos") };
            l.attrs[sprites_shader.ATTR_sprites_texcoord] = .{ .format = .FLOAT2, .offset = @offsetOf(SpriteVertex, "uv") };
            l.attrs[sprites_shader.ATTR_sprites_texidx] = .{ .format = .INT, .offset = @offsetOf(SpriteVertex, "tex_idx") };
            break :init l;
        },
        .index_type = .UINT16,
        .cull_mode = .NONE,
        .sample_count = 1,
        .depth = .{
            .pixel_format = .DEPTH,
            .compare = .ALWAYS,
            .write_enabled = false,
        },
        .colors = init: {
            // Try @splat
            var c: [8]sg.ColorTargetState = @splat(.{});
            c[0].pixel_format = .RGBA8;
            c[0].blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                .op_rgb = .ADD,
                .src_factor_alpha = .ONE,
                .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
                .op_alpha = .ADD,
            };
            break :init c;
        },
    });

    render.display.pip = sg.makePipeline(.{
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

const Spritesheet = enum { tilemap, character, interface };

fn drawTile(spritesheet: Spritesheet, x: i32, y: i32, frame_x: i32, frame_y: i32) [4]SpriteVertex {
    var spritesheet_width: f32 = undefined;
    var spritesheet_height: f32 = undefined;
    switch (spritesheet) {
        .tilemap => {
            spritesheet_width = 288.0;
            spritesheet_height = 208.0;
        },
        .character => {
            spritesheet_width = 432.0;
            spritesheet_height = 288.0;
        },
        .interface => {
            spritesheet_width = 288.0;
            spritesheet_height = 176.0;
        },
    }

    const world_x = @as(f32, @floatFromInt(x)) * tile_size;
    const world_y = @as(f32, @floatFromInt(y)) * tile_size;

    // Frame coordinates are in normalized UV space from [0.0, 1.0]
    const frame_u = @as(f32, @floatFromInt(frame_x)) * tile_size / spritesheet_width;
    const frame_v = @as(f32, @floatFromInt(frame_y)) * tile_size / spritesheet_height;
    const frame_w = tile_size / spritesheet_width;
    const frame_h = tile_size / spritesheet_height;

    const tex_idx = @intFromEnum(spritesheet);
    var vertices: [4]SpriteVertex = undefined;
    // Bottom-left
    vertices[0] = .{
        .pos = .{ world_x, world_y + tile_size },
        .uv = .{ frame_u, frame_v + frame_h },
        .tex_idx = tex_idx,
    };
    // Bottom-right
    vertices[1] = .{
        .pos = .{ world_x + tile_size, world_y + tile_size },
        .uv = .{ frame_u + frame_w, frame_v + frame_h },
        .tex_idx = tex_idx,
    };
    // Top-left
    vertices[2] = .{
        .pos = .{ world_x, world_y },
        .uv = .{ frame_u, frame_v },
        .tex_idx = tex_idx,
    };
    // Top-right
    vertices[3] = .{
        .pos = .{ world_x + tile_size, world_y },
        .uv = .{ frame_u + frame_w, frame_v },
        .tex_idx = tex_idx,
    };
    return vertices;
}

const FrameLookup = std.StaticStringMap([2]i32);
var letters: FrameLookup = undefined;

export fn frame() void {
    const dt: f32 = @floatCast(sapp.frameDuration() * 60);
    _ = dt;

    sg.beginPass(.{
        .action = render.sprites.pass_action,
        .attachments = render.sprites.attachments,
    });
    sg.applyPipeline(render.sprites.pip);
    sg.applyBindings(render.sprites.bind);
    const sprites_mvp: Mat4 = .ortho(0.0, logical_width, logical_height, 0.0, -1.0, 0.0);
    sg.applyUniforms(sprites_shader.UB_vs_params, sg.asRange(&sprites_mvp));
    // Update buffers
    var sprite_vertex_data: [max_sprites * 4]SpriteVertex = std.mem.zeroes([max_sprites * 4]SpriteVertex);
    var sprite_count: u32 = 0;

    // Bottom-left
    sprite_vertex_data[0] = .{
        .pos = .{ 0.0, 32.0 },
        .uv = .{ 0.0, 1.0 },
        .tex_idx = 2,
    };
    // Bottom-right
    sprite_vertex_data[1] = .{
        .pos = .{ 32.0, 32.0 },
        .uv = .{ 1.0, 1.0 },
        .tex_idx = 2,
    };
    // Top-left
    sprite_vertex_data[2] = .{
        .pos = .{ 0.0, 0.0 },
        .uv = .{ 0.0, 0.0 },
        .tex_idx = 2,
    };
    // Top-right
    sprite_vertex_data[3] = .{
        .pos = .{ 32.0, 0.0 },
        .uv = .{ 1.0, 0.0 },
        .tex_idx = 2,
    };
    sprite_count += 1;

    sprite_vertex_data[4..][0..4].* = drawTile(.tilemap, 2, 2, 0, 0);
    sprite_count += 1;

    sprite_vertex_data[8..][0..4].* = drawTile(.interface, 3, 3, 0, 9);
    sprite_count += 1;

    var ui_x: i32 = 4;
    const ui_y = 4;
    for ("aaaaaa") |char| {
        const str = &[_]u8{char};
        const letter_frame = letters.get(str);
        if (letter_frame) |l| {
            const x, const y = l;
            sprite_vertex_data[sprite_count * 4 ..][0..4].* = drawTile(.interface, ui_x, ui_y, x, y);
            ui_x += 1;
            sprite_count += 1;
        }
    }

    sg.updateBuffer(
        render.sprites.bind.vertex_buffers[0],
        sg.asRange(sprite_vertex_data[0 .. sprite_count * 4]),
    );
    sg.draw(0, sprite_count * 6, 1);
    sg.endPass();

    sg.beginPass(.{
        .action = render.display.pass_action,
        .swapchain = sglue.swapchain(),
    });
    sg.applyPipeline(render.display.pip);
    sg.applyBindings(render.display.bind);
    // TODO: This mvp is unnecessary.
    const mvp: Mat4 = .ortho(0.0, logical_width, 0.0, logical_height, -1.0, 1.0);
    sg.applyUniforms(display_shader.UB_vs_params, sg.asRange(&mvp));
    sg.draw(0, 6, 1);

    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sg.shutdown();
}

pub fn main() !void {
    letters = FrameLookup.initComptime(.{.{ "a", .{ 0, 9 } }});

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
