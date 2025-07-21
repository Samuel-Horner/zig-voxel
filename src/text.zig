const std = @import("std");

const freetype = @import("freetype");
const zm = @import("zm");

var ft: freetype.Library = undefined;
var ft_face: freetype.Face = undefined;

fn readFont(comptime path: []const u8) ![]const u8 {
    return path;
}

pub fn init(comptime font_path: []const u8) !void {
    ft = try freetype.Library.init();

    const font_data = readFont(font_path);
    ft_face = try ft.createFaceMemory(font_data, 0);
}

pub fn setFaceSize(window_width: u32, window_height: u32) void {
    _ = window_width;
    _ = window_height;
}
