const display_height = 768;
const display_width = 1024;

const tile_size = 16;
const logical_width = 256.0;
const logical_height = 192.0;
const max_sprites = 1_000;

const SpriteVertex = struct {
    pos: [2]f32,
    uv: [2]f32,
    tint_color: [4]f32,
    tex_idx: u32, // Matches Spritesheet enum
};

const DisplayVertex = struct {
    pos: [2]f32,
    uv: [2]f32,
};

const Spritesheet = enum { tilemap, character, interface };

const sprites = struct {
    var attachments: sg.Attachments = .{};
    var pip: sg.Pipeline = .{};
    var bind: sg.Bindings = .{};
    var pass_action: sg.PassAction = .{};
};
const gaussian = struct {
    var attachments: sg.Attachments = .{};
    var pip: sg.Pipeline = .{};
    // Gaussian blur uses two passes, first pass uses the texture from the sprites shader
    // and draws to another texture. Second pass then uses a view to the other texture
    // and draws to the sprites texture. Then the display shader can just read from the
    // same texture as usual to render it to the screen.
    var first_bind: sg.Bindings = .{};
    var second_bind: sg.Bindings = .{};
    var pass_action: sg.PassAction = .{};
};
const display = struct {
    var pip: sg.Pipeline = .{};
    var bind: sg.Bindings = .{};
    var pass_action: sg.PassAction = .{};
};

var sprite_vertex_data: [max_sprites * 4]SpriteVertex = std.mem.zeroes([max_sprites * 4]SpriteVertex);
var sprite_count: u32 = 0;

pub fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // Initialize sprite pass

    sprites.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 1.0, .g = 0.0, .b = 0.0 },
    };

    sprites.bind.vertex_buffers[0] = sg.makeBuffer(.{
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
    sprites.bind.index_buffer = sg.makeBuffer(.{
        .data = sg.asRange(&indices),
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

    sprites.bind.views[0] = sg.makeView(.{
        .texture = .{ .image = tilemap_image },
    });
    sprites.bind.views[1] = sg.makeView(.{
        .texture = .{ .image = characters_image },
    });
    sprites.bind.views[2] = sg.makeView(.{
        .texture = .{ .image = interface_image },
    });
    sprites.bind.samplers[0] = sg.makeSampler(.{
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        .wrap_u = .CLAMP_TO_EDGE,
        .wrap_v = .CLAMP_TO_EDGE,
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
    sprites.attachments = .{
        .colors = init: {
            var c: [8]sg.View = @splat(.{});
            c[0] = color_att_view;
            break :init c;
        },
        .depth_stencil = depth_att_view,
    };

    sprites.pip = sg.makePipeline(.{
        .shader = sg.makeShader(sprites_shader.spritesShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[sprites_shader.ATTR_sprites_position] = .{ .format = .FLOAT2, .offset = @offsetOf(SpriteVertex, "pos") };
            l.attrs[sprites_shader.ATTR_sprites_texcoord] = .{ .format = .FLOAT2, .offset = @offsetOf(SpriteVertex, "uv") };
            l.attrs[sprites_shader.ATTR_sprites_tint_color] = .{ .format = .FLOAT4, .offset = @offsetOf(SpriteVertex, "tint_color") };
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

    // Initialize gaussian pass

    gaussian.pass_action.colors[0] = .{
        .load_action = .DONTCARE,
        .store_action = .STORE,
    };

    const gaussian_vertices = [_]DisplayVertex{
        // UV coordinates are (0, 0) from the lower-left
        .{ .pos = .{ -1.0, -1.0 }, .uv = .{ 0.0, 0.0 } }, // bottom-left
        .{ .pos = .{ 1.0, -1.0 }, .uv = .{ 1.0, 0.0 } }, // bottom-right
        .{ .pos = .{ -1.0, 1.0 }, .uv = .{ 0.0, 1.0 } }, // top-left
        .{ .pos = .{ 1.0, 1.0 }, .uv = .{ 1.0, 1.0 } }, // top-right
    };
    const gaussian_indices = [_]u16{ 0, 1, 2, 1, 3, 2 };
    gaussian.second_bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&gaussian_vertices),
        .usage = .{ .vertex_buffer = true },
    });
    gaussian.second_bind.index_buffer = sg.makeBuffer(.{
        .data = sg.asRange(&gaussian_indices),
        .usage = .{ .index_buffer = true },
    });

    gaussian.first_bind.vertex_buffers[0] = gaussian.second_bind.vertex_buffers[0];
    gaussian.first_bind.index_buffer = gaussian.second_bind.index_buffer;

    var other_image_desc: sg.ImageDesc = .{
        .width = @intFromFloat(logical_width),
        .height = @intFromFloat(logical_height),
        .pixel_format = .RGBA8,
        .sample_count = 1,
        .usage = .{ .color_attachment = true },
    };
    const other_color_image = sg.makeImage(other_image_desc);
    other_image_desc.pixel_format = .DEPTH;
    other_image_desc.usage = .{ .depth_stencil_attachment = true };
    const other_depth_image = sg.makeImage(other_image_desc);

    const other_color_att_view = sg.makeView(.{
        .color_attachment = .{
            .image = other_color_image,
        },
    });
    const other_depth_att_view = sg.makeView(.{
        .depth_stencil_attachment = .{
            .image = other_depth_image,
        },
    });
    gaussian.attachments = .{
        .colors = init: {
            var c: [8]sg.View = @splat(.{});
            c[0] = other_color_att_view;
            break :init c;
        },
        .depth_stencil = other_depth_att_view,
    };

    gaussian.second_bind.samplers[0] = sg.makeSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
        .wrap_u = .CLAMP_TO_EDGE,
        .wrap_v = .CLAMP_TO_EDGE,
    });
    gaussian.second_bind.views[0] = sg.makeView(.{
        .texture = .{
            .image = other_color_image,
        },
    });

    gaussian.first_bind.samplers[0] = gaussian.second_bind.samplers[0];
    gaussian.first_bind.views[0] = sg.makeView(.{
        .texture = .{
            .image = color_image,
        },
    });

    gaussian.pip = sg.makePipeline(.{
        .shader = sg.makeShader(gaussian_shader.gaussianShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[display_shader.ATTR_display_position] = .{ .format = .FLOAT2, .offset = @offsetOf(DisplayVertex, "pos") };
            l.attrs[display_shader.ATTR_display_texcoord] = .{ .format = .FLOAT2, .offset = @offsetOf(DisplayVertex, "uv") };
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

    // Initialize display pass

    display.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.0, .b = 1.0 },
        .store_action = .DONTCARE,
    };

    const display_vertices = [_]DisplayVertex{
        // UV coordinates are (0, 0) from the lower-left
        .{ .pos = .{ -1.0, -1.0 }, .uv = .{ 0.0, 0.0 } }, // bottom-left
        .{ .pos = .{ 1.0, -1.0 }, .uv = .{ 1.0, 0.0 } }, // bottom-right
        .{ .pos = .{ -1.0, 1.0 }, .uv = .{ 0.0, 1.0 } }, // top-left
        .{ .pos = .{ 1.0, 1.0 }, .uv = .{ 1.0, 1.0 } }, // top-right
    };
    const display_indices = [_]u16{ 0, 1, 2, 1, 3, 2 };
    display.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&display_vertices),
        .usage = .{ .vertex_buffer = true },
    });
    display.bind.index_buffer = sg.makeBuffer(.{
        .data = sg.asRange(&display_indices),
        .usage = .{ .index_buffer = true },
    });

    display.bind.samplers[0] = sg.makeSampler(.{
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        .wrap_u = .CLAMP_TO_EDGE,
        .wrap_v = .CLAMP_TO_EDGE,
    });

    display.bind.views[0] = sg.makeView(.{
        .texture = .{
            .image = color_image,
        },
    });

    display.pip = sg.makePipeline(.{
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

fn calculateSpriteVertices(spritesheet: Spritesheet, x: f32, y: f32, frame_x: u32, frame_y: u32, tint_color: [4]f32) [4]SpriteVertex {
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

    const world_x = x * tile_size;
    const world_y = y * tile_size;
    std.debug.assert(world_x < logical_width);
    std.debug.assert(world_y < logical_height);

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
        .tint_color = tint_color,
        .tex_idx = tex_idx,
    };
    // Bottom-right
    vertices[1] = .{
        .pos = .{ world_x + tile_size, world_y + tile_size },
        .uv = .{ frame_u + frame_w, frame_v + frame_h },
        .tint_color = tint_color,
        .tex_idx = tex_idx,
    };
    // Top-left
    vertices[2] = .{
        .pos = .{ world_x, world_y },
        .uv = .{ frame_u, frame_v },
        .tint_color = tint_color,
        .tex_idx = tex_idx,
    };
    // Top-right
    vertices[3] = .{
        .pos = .{ world_x + tile_size, world_y },
        .uv = .{ frame_u + frame_w, frame_v },
        .tint_color = tint_color,
        .tex_idx = tex_idx,
    };
    return vertices;
}

const default_tint: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 };
pub fn drawTile(spritesheet: Spritesheet, x: f32, y: f32, frame_x: u32, frame_y: u32) void {
    const vertices = calculateSpriteVertices(spritesheet, x, y, frame_x, frame_y, default_tint);
    sprite_vertex_data[sprite_count * 4 ..][0..4].* = vertices;
    sprite_count += 1;
}

pub fn drawTileTinted(spritesheet: Spritesheet, x: f32, y: f32, frame_x: u32, frame_y: u32, tint_color: [4]f32) void {
    const vertices = calculateSpriteVertices(spritesheet, x, y, frame_x, frame_y, tint_color);
    sprite_vertex_data[sprite_count * 4 ..][0..4].* = vertices;
    sprite_count += 1;
}

pub fn drawTileRotated(spritesheet: Spritesheet, x: f32, y: f32, frame_x: u32, frame_y: u32, rotation: f32) void {
    var vertices = calculateSpriteVertices(spritesheet, x, y, frame_x, frame_y, default_tint);
    const center_x = x * tile_size + 8.0;
    const center_y = y * tile_size + 8.0;
    for (&vertices) |*vertex| {
        const relative_x = vertex.pos[0] - center_x;
        const relative_y = vertex.pos[1] - center_y;
        const rotated_x = relative_x * @cos(rotation) - relative_y * @sin(rotation);
        const rotated_y = relative_y * @cos(rotation) + relative_x * @sin(rotation);
        vertex.pos[0] = rotated_x + center_x;
        vertex.pos[1] = rotated_y + center_y;
    }
    sprite_vertex_data[sprite_count * 4 ..][0..4].* = vertices;
    sprite_count += 1;
}

fn char_to_frame(char: u8) ?[2]u32 {
    return switch (char) {
        '0' => .{ 3, 8 },
        '1' => .{ 4, 8 },
        '2' => .{ 5, 8 },
        '3' => .{ 6, 8 },
        '4' => .{ 7, 8 },
        '5' => .{ 8, 8 },
        '6' => .{ 9, 8 },
        '7' => .{ 10, 8 },
        '8' => .{ 11, 8 },
        '9' => .{ 12, 8 },
        'a', 'A' => .{ 0, 9 },
        'b', 'B' => .{ 1, 9 },
        'c', 'C' => .{ 2, 9 },
        'd', 'D' => .{ 3, 9 },
        'e', 'E' => .{ 4, 9 },
        'f', 'F' => .{ 5, 9 },
        'g', 'G' => .{ 6, 9 },
        'h', 'H' => .{ 7, 9 },
        'i', 'I' => .{ 8, 9 },
        'j', 'J' => .{ 9, 9 },
        'k', 'K' => .{ 10, 9 },
        'l', 'L' => .{ 11, 9 },
        'm', 'M' => .{ 12, 9 },
        'n', 'N' => .{ 0, 10 },
        'o', 'O' => .{ 1, 10 },
        'p', 'P' => .{ 2, 10 },
        'q', 'Q' => .{ 3, 10 },
        'r', 'R' => .{ 4, 10 },
        's', 'S' => .{ 5, 10 },
        't', 'T' => .{ 6, 10 },
        'u', 'U' => .{ 7, 10 },
        'v', 'V' => .{ 8, 10 },
        'w', 'W' => .{ 9, 10 },
        'x', 'X' => .{ 10, 10 },
        'y', 'Y' => .{ 11, 10 },
        'z', 'Z' => .{ 12, 10 },
        else => null,
    };
}

pub fn drawText(start_x: f32, start_y: f32, text: []const u8, is_bold: bool) void {
    var ui_x: f32 = start_x;
    for (text) |char| {
        const letter_frame = char_to_frame(char);
        if (letter_frame) |l| {
            const x, var y = l;
            if (is_bold) {
                y -= 3;
            }
            // w and m have wider sprites compared to everything else
            const wide_offset = 2.0 / 16.0;
            if (char == 'w' or char == 'm') {
                ui_x += 1.0 * wide_offset;
            }
            drawTile(.interface, ui_x, start_y, x, y);
            if (char == 'w' or char == 'm') {
                ui_x += 1.0 * wide_offset;
            }
            ui_x += 0.5;
        } else {
            ui_x += 0.25;
        }
    }
}

pub fn beginFrame() void {
    sprite_count = 0;
}

pub fn renderLevel(level: *const GameLevel) void {
    var layer_idx: usize = 3;
    while (layer_idx > 0) {
        layer_idx -= 1;
        const layer = level.layers[layer_idx];
        for (layer) |row| {
            for (row) |tile| {
                // Tiles are always full so we need to skip empty tiles, might need to use an arraylist.
                if (tile.pos[0] == 0 and tile.pos[1] == 0 and tile.tex[0] == 0 and tile.tex[1] == 0) {
                    continue;
                }
                drawTile(
                    .tilemap,
                    @floatFromInt(tile.pos[0]),
                    @floatFromInt(tile.pos[1]),
                    tile.tex[0],
                    tile.tex[1],
                );
            }
        }
    }

    drawText(4.0, 4.0, "0123456789wooow", false);
}

var time_elapsed: f32 = 0;
var blur_strength: f32 = 0.0;
var blur_more: bool = true;
pub fn endFrame(use_blur: bool) void {
    time_elapsed += @as(f32, @floatCast(sapp.frameDuration()));
    if (use_blur) {
        if (blur_more) {
            blur_strength += 0.02;
            if (blur_strength > 2.0) {
                blur_more = false;
                blur_strength = 2.0;
            }
        } else {
            blur_strength -= 0.02;
            if (blur_strength < 0.0) {
                blur_more = true;
                blur_strength = 0.0;
            }
        }
    }

    // Update the buffer before doing any pipeline:
    // Trying to update the buffer during the pipeline seemed to cause an issue
    // when removing sprits where the buffer was the value at the previous frame
    // so it would have the vertex buffer of the last frame but the sprite count
    // of the current frame.
    sg.updateBuffer(
        sprites.bind.vertex_buffers[0],
        sg.asRange(sprite_vertex_data[0 .. sprite_count * 4]),
    );

    // Sprites pass
    sg.beginPass(.{
        .action = sprites.pass_action,
        .attachments = sprites.attachments,
    });
    sg.applyPipeline(sprites.pip);
    sg.applyBindings(sprites.bind);
    const sprites_mvp: Mat4 = .ortho(0.0, logical_width, logical_height, 0.0, -1.0, 0.0);
    sg.applyUniforms(sprites_shader.UB_vs_params, sg.asRange(&sprites_mvp));
    sg.draw(0, sprite_count * 6, 1);
    sg.endPass();

    if (use_blur) {
        // First gaussian pass - take the sprite results and blur them
        sg.beginPass(.{
            .action = gaussian.pass_action,
            .attachments = gaussian.attachments,
        });
        sg.applyPipeline(gaussian.pip);
        sg.applyBindings(gaussian.first_bind);
        const first_blur: gaussian_shader.VsParams = .{
            .direction = .{ 0.0, 1.0 },
            .resolution = .{ logical_width, logical_height },
            .blur_strength = blur_strength,
        };
        sg.applyUniforms(gaussian_shader.UB_vs_params, sg.asRange(&first_blur));
        sg.draw(0, 6, 1);
        sg.endPass();

        // Second gaussian pass - take the first results pass and render them to the sprites image
        sg.beginPass(.{
            .action = gaussian.pass_action,
            .attachments = sprites.attachments,
        });
        sg.applyPipeline(gaussian.pip);
        sg.applyBindings(gaussian.second_bind);
        const second_blur: gaussian_shader.VsParams = .{
            .direction = .{ 1.0, 0.0 },
            .resolution = .{ logical_width, logical_height },
            .blur_strength = blur_strength,
        };
        sg.applyUniforms(gaussian_shader.UB_vs_params, sg.asRange(&second_blur));
        sg.draw(0, 6, 1);
        sg.endPass();
    }

    // Display pass
    sg.beginPass(.{
        .action = display.pass_action,
        .swapchain = sglue.swapchain(),
    });
    sg.applyPipeline(display.pip);
    sg.applyBindings(display.bind);
    // Binding a single float with uniforms
    // const display_shader_params: display_shader.VsParams = .{
    //     .u_time = time_elapsed,
    // };
    // sg.applyUniforms(display_shader.UB_vs_params, sg.asRange(&display_shader_params));
    sg.draw(0, 6, 1);
    sg.endPass();

    sg.commit();
}

const std = @import("std");
const sokol = @import("sokol");
const zstbi = @import("zstbi");
const sapp = sokol.app;
const sg = sokol.gfx;
const sglue = sokol.glue;
const slog = sokol.log;
const math = @import("math.zig");
const Mat4 = math.Mat4;
const display_shader = @import("shaders/display.zig");
const gaussian_shader = @import("shaders/gaussian.zig");
const sprites_shader = @import("shaders/sprites.zig");
const GameLevel = @import("level.zig").GameLevel;
