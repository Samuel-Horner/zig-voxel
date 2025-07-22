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
        // debug.log("Parsing Argument: {s}", .{arg});
        
        // Long form flags
        if (std.mem.eql(u8, arg[0..2], "--")) {
            if (std.mem.eql(u8, arg, "--force-wayland")) { force_wayland = true; continue; }
        }
        // Short form flags
        else if (arg[0] == '-') {
            for (arg[1..]) |flag| {
                if (flag == 'w') { force_wayland = true; continue; }

                debug.err("Unkwon flag: {c}", .{flag});
            }
            continue;
        }

        debug.err("Unkown argument: {s}", .{arg});
    }
}
