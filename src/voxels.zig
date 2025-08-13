const std = @import("std");

const debug = @import("debug.zig");

pub const Voxel = struct {
    id: u32,
    name: []const u8,

    @"opaque": bool,
};

pub fn isOpaque(voxel: u32) bool {
    return voxel_registry[voxel].@"opaque";
}

pub const voxel_registry = [_]Voxel{
    .{ .id = 0, .name = "Empty", .@"opaque" = false },
    .{ .id = 1, .name = "Solid", .@"opaque" = true },
    .{ .id = 2, .name = "Special", .@"opaque" = true },
};

pub const empty: u32 = 0;
pub const solid: u32 = 1;
pub const special: u32 = 2;
