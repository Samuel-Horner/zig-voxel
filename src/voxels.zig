const std = @import("std");

const debug = @import("debug.zig");

const Color = packed struct { r: u4, g: u4, b: u4 };

pub const Voxel = struct {
    id: u32,
    name: []const u8,

    @"opaque": bool,
    color: Color,
};

pub fn isOpaque(voxel: u32) bool {
    return voxel_registry[voxel].@"opaque";
}

pub fn color(voxel: u32) Color {
    return voxel_registry[voxel].color;
}

pub const voxel_registry = [_]Voxel{
    .{ .id = 0, .name = "Empty", .@"opaque" = false, .color = .{ .r = 0, .g = 0, .b = 0 } },
    .{ .id = 1, .name = "Stone", .@"opaque" = true, .color = .{ .r = 10, .g = 10, .b = 10 } },
    .{ .id = 2, .name = "Grass", .@"opaque" = true, .color = .{ .r = 7, .g = 14, .b = 2 } },
    .{ .id = 3, .name = "Snow", .@"opaque" = true, .color = .{ .r = 15, .g = 15, .b = 15 } },
};

pub const empty: u32 = 0;
pub const stone: u32 = 1;
pub const grass: u32 = 2;
pub const snow: u32 = 3;
