const tile_size = 16;
const width_in_tiles = 16;
const height_in_tiles = 12;

const Tile = struct {
    pos: [2]u32,
    tex: [2]u32,
    tex_idx: usize,
};
pub const Tilemap = struct {
    const Self = @This();
    bounds: [width_in_tiles * height_in_tiles]bool,
    layers: [3]std.ArrayList(Tile),

    pub fn canMoveTo(self: *Self, x: i32, y: i32) bool {
        if (x < 0 or y < 0 or x >= width_in_tiles or y >= height_in_tiles) return false;
        const safe_x: usize = @intCast(x);
        const safe_y: usize = @intCast(y);
        return self.bounds[safe_x + (width_in_tiles * safe_y)];
    }
};

const LdtkTile = struct {
    px: [2]u32,
    src: [2]u32,
};
const LdtkLayer = struct {
    gridTiles: []const LdtkTile,
};
const LdtkLevel = struct {
    identifier: []const u8,
    layerInstances: []const LdtkLayer,
};
const LdtkData = struct {
    iid: []const u8,
    levels: []const LdtkLevel,
};
const ldtk_str = @embedFile("assets/level1.ldtk");
pub fn loadTilemap(allocator: Allocator, level_name: []const u8) !Tilemap {
    const parsed = try std.json.parseFromSlice(
        LdtkData,
        allocator,
        ldtk_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    var tilemap: Tilemap = .{
        .bounds = @splat(true),
        .layers = .{ .empty, .empty, .empty },
    };

    const ldtk_result: LdtkData = parsed.value;
    for (ldtk_result.levels) |ldtk_level| {
        if (!std.mem.eql(u8, ldtk_level.identifier, level_name)) continue;
        // If it's not the bottom layer, add to the hitmap
        // Bottom layer is the last layer 2
        var layer_idx: usize = 0;
        for (ldtk_level.layerInstances) |ldtk_layer| {
            defer layer_idx += 1;
            std.debug.print("layer {} # tiles: {}\n", .{ 2 - layer_idx, ldtk_layer.gridTiles.len });
            var tiles = &tilemap.layers[layer_idx];
            try tiles.ensureUnusedCapacity(allocator, ldtk_layer.gridTiles.len);
            for (ldtk_layer.gridTiles) |ldtk_tile| {
                const tile_x = ldtk_tile.px[0] / 16;
                const tile_y = ldtk_tile.px[1] / 16;
                const tex_x = ldtk_tile.src[0] / 16;
                const tex_y = ldtk_tile.src[1] / 16;
                tiles.appendAssumeCapacity(.{
                    .pos = .{ tile_x, tile_y },
                    .tex = .{ tex_x, tex_y },
                    .tex_idx = 0,
                });
                if (layer_idx < 2) {
                    tilemap.bounds[tile_x + (tile_y * width_in_tiles)] = false;
                }
            }
        }
        // Only layers we have are the ground, buildings and then objects
        std.debug.assert(layer_idx < 4);
    }

    std.debug.print("{any}\n", .{tilemap.bounds});

    return tilemap;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
