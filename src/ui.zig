pub fn drawDialog(char_name: []const u8, dialog: []const u8) void {
    const start_x = 0;
    const start_y = 7;
    const end_x = 15;
    const end_y = 11;

    // dialog box texture 15-17 on x, 0-2 on y
    renderer.drawTile(.interface, @floatFromInt(start_x), @floatFromInt(start_y), 15, 0);
    renderer.drawTile(.interface, @floatFromInt(end_x), @floatFromInt(start_y), 17, 0);
    renderer.drawTile(.interface, @floatFromInt(start_x), @floatFromInt(end_y), 15, 2);
    renderer.drawTile(.interface, @floatFromInt(end_x), @floatFromInt(end_y), 17, 2);

    const border_x_start = start_x + 1;
    for (border_x_start..end_x) |border_x| {
        renderer.drawTile(.interface, @floatFromInt(border_x), start_y, 16, 0);
        renderer.drawTile(.interface, @floatFromInt(border_x), end_y, 16, 2);
    }
    const border_y_start = start_y + 1;
    for (border_y_start..end_y) |border_y| {
        renderer.drawTile(.interface, start_x, @floatFromInt(border_y), 15, 1);
        renderer.drawTile(.interface, end_x, @floatFromInt(border_y), 17, 1);
    }

    const middle_x_start = border_x_start;
    const middle_y_start = border_y_start;
    const middle_x_end = end_x;
    const middle_y_end = end_y;
    for (middle_x_start..middle_x_end) |middle_x| {
        for (middle_y_start..middle_y_end) |middle_y| {
            renderer.drawTile(.interface, @floatFromInt(middle_x), @floatFromInt(middle_y), 16, 1);
        }
    }

    const text_start_x = start_x + 0.25;
    const text_start_y = start_y + 0.375;
    renderer.drawText(text_start_x, text_start_y, char_name, true);
    renderer.drawText(text_start_x, text_start_y + 0.875, dialog, false);
    renderer.drawText(text_start_x, text_start_y + 0.875 + 0.8125, dialog, false);
    renderer.drawText(text_start_x, text_start_y + 0.875 + 0.8125 + 0.8125, dialog, false);
    renderer.drawText(text_start_x, text_start_y + 0.875 + 0.8125 + 0.8125 + 0.8125, dialog, false);
}

const std = @import("std");
const renderer = @import("renderer.zig");
