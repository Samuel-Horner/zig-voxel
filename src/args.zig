const std = @import("std");
const debug = @import("debug.zig");

pub var force_wayland: bool = false;

pub fn parse() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(gpa_alloc);
    defer std.process.argsFree(gpa_alloc, args);

    for (args[1..]) |arg| {
        debug.log("Parsing Argument: {s}", .{arg});
        if (std.mem.eql(u8, arg, "--force-wayland")) { force_wayland = true; }
    }
}
