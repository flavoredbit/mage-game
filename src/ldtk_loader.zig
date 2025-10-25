const LdtkData = struct {
    iid: []const u8,
};

pub fn main() !void {
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

    std.debug.print("iid: {s}\n", .{parsed.value.iid});
}

const std = @import("std");
