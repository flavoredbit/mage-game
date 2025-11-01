pub fn drawDialog(char_name: []const u8, dialog: []const u8) void {
    _ = char_name;
    _ = dialog;
    const start_x = 0.0;
    const start_y = 7.0;
    const end_x = 15.0;
    const end_y = 11.0;

    // dialog box texture 15-17 on x, 0-2 on y
    // draw corners
    renderer.drawTile(.interface, start_x, start_y, 15, 0);
    renderer.drawTile(.interface, end_x, start_y, 17, 0);
    renderer.drawTile(.interface, start_x, end_y, 15, 2);
    renderer.drawTile(.interface, end_x, end_y, 17, 2);
}

const std = @import("std");
const renderer = @import("renderer.zig");
