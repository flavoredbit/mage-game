const GridTile = struct {
    px: [2]u32,
    src: [2]u32,
};
const Layer = struct {
    gridTiles: []const GridTile,
};
const Level = struct {
    identifier: []const u8,
    layerInstances: []const Layer,
};
const LdtkData = struct {
    iid: []const u8,
    levels: []const Level,
};

const tile_size = 16;
const width_in_tiles = 16;
const height_in_tiles = 12;

const GameTile = struct {
    pos: [2]u32,
    tex: [2]u32,
    tex_idx: usize,
};
const GameLevel = struct {
    layers: [3][height_in_tiles][width_in_tiles]GameTile,
};
var game_level: GameLevel = undefined;

pub fn main() !void {
    game_level.layers = std.mem.zeroes(@FieldType(GameLevel, "layers"));

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const ldtk_str = @embedFile("assets/level1.ldtk");

    const parsed = try std.json.parseFromSlice(
        LdtkData,
        allocator,
        ldtk_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const result: LdtkData = parsed.value;
    for (result.levels) |level| {
        var layer_idx: usize = 0;
        for (level.layerInstances) |layer| {
            defer layer_idx += 1;
            std.debug.print("{s} has {} tiles\n", .{ level.identifier, layer.gridTiles.len });
            for (layer.gridTiles) |gridTile| {
                const tile_x = gridTile.px[0] / 16;
                const tile_y = gridTile.px[1] / 16;
                const tex_x = gridTile.src[0] / 16;
                const tex_y = gridTile.src[1] / 16;
                game_level.layers[layer_idx][tile_y][tile_x] = .{
                    .pos = .{ tile_x, tile_y },
                    .tex = .{ tex_x, tex_y },
                    .tex_idx = 0,
                };
            }
        }
    }

    for (game_level.layers) |layer| {
        for (layer) |row| {
            std.debug.print(".{{", .{});
            for (row) |tile| {
                std.debug.print(".{{ .pos = .{{ {}, {} }}, .tex = .{{ {}, {} }}, .tex_idx = {} }},", .{
                    tile.pos[0],
                    tile.pos[1],
                    tile.tex[0],
                    tile.tex[1],
                    tile.tex_idx,
                });
            }
            std.debug.print("}},\n", .{});
        }
    }
}

const std = @import("std");
