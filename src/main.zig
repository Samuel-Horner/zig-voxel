const std = @import("std");
const builtin = @import("builtin");

const glfw = @import("glfw");
const gl = @import("gl");
const zm = @import("zm");

const engine = @import("engine/engine.zig");
const text = @import("engine/text.zig");
const world = @import("world.zig");
const debug = @import("debug.zig");
const player = @import("player.zig");
const args = @import("args.zig");

// const vertex_source: []const u8 = @embedFile("shader/text_vert.glsl");
// const fragment_source: []const u8 = @embedFile("shader/text_frag.glsl");

const vertex_source: []const u8 =
    \\  #version 460 core
    \\  
    \\  uniform mat4 view;
    \\  uniform mat4 proj;
    \\
    \\  layout (location = 0) in vec3 vertex_pos;
    \\  
    \\  void main()
    \\  {    
    \\      gl_Position = proj * view * vec4(vertex_pos, 1.);
    \\  }  
;
const fragment_source: []const u8 =
    \\  #version 460 core
    \\  
    \\  out vec4 color;
    \\
    \\  void main()
    \\  {
    \\      color = vec4(1.);
    \\  }  
;

const vertices = [_]f32{ -0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0 };
const indicies = [_]c_uint{ 0, 1, 2 };

pub fn main() !void {
    // ##### Allocator Setup #####
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    // defer {
    //     const gpa_deinit_status = gpa.deinit();
    //     if (gpa_deinit_status == .leak) { debug.err("GPA detected memory leaks when deinit-ing.", .{}); }
    // }
    defer if (gpa.deinit() == .leak) {
        debug.err("GPA detected memory leaks when deinit-ing.", .{});
    };

    // ##### Debug Info #####
    // Zig version
    debug.log("Zig {s}.", .{builtin.zig_version_string});

    // // CWD
    // // TODO: Find a better way to do this
    // // see https://github.com/ziglang/zig/issues/19353
    // var path_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer path_arena.deinit();

    // debug.log("CWD: {s}.", .{
    //     try std.fs.cwd().realpathAlloc(path_arena.allocator(), ".")
    // });

    // ##### Args #####
    try args.parse();

    // ##### Engine Init #####
    try engine.init(1200, 800, "JetBrainsMonoNerdFont-Regular.ttf", gpa.allocator(), .{ .force_wayland = args.force_wayland });
    defer engine.deinit();

    // ##### Player Init #####
    try player.init(.{ 0, 0, -1 }, 10, 0.05, 90);

    // ##### Hello triangle #####
    var vertex_buffer = engine.VertexBuffer.init(vertices[0..], indicies[0..], &.{3}, .{});

    // Create Program
    var program: engine.Program = try engine.Program.init(vertex_source, fragment_source);
    defer program.deinit();

    // Since we will allways set both every frame, no need to store uniform indexes.
    _ = try program.registerUniform("view", player.applyView);
    _ = try program.registerUniform("proj", player.applyProj);

    // ##### Timer Init #####
    var frame_timer = try std.time.Timer.start();
    var debug_info_timer = try std.time.Timer.start();

    // ##### Render Loop #####
    var f11_down = false;

    var frame_count: u32 = 0;
    var fps: u32 = 0;

    while (!engine.window.shouldClose()) {
        if (engine.keyPressed(engine.Key.escape)) {
            engine.window.setShouldClose(true);
        }

        if (engine.keyPressed(engine.Key.F11)) {
            if (!f11_down) {
                engine.toggleFullScreen();
                f11_down = true;
            }
        } else {
            f11_down = false;
        }

        // Time Methods
        const delta_time: f32 = @as(f32, @floatFromInt(frame_timer.lap())) / 1e9;

        // Player Tick
        player.tick(delta_time);

        // Render
        engine.clearViewport();

        program.use();
        program.applyAllUniforms();

        vertex_buffer.draw();

        // Steady Debug Hud
        frame_count += 1;
        if (debug_info_timer.read() > 1e9) {
            fps = frame_count;
            frame_count = 0;

            _ = debug_info_timer.lap();
        }

        var debug_str_buf: [128]u8 = undefined;
        const debug_str = std.fmt.bufPrint(&debug_str_buf, "FPS: {}", .{fps}) catch "Buffer Print Error";
        text.renderText(debug_str, .{ 10, 10 }, 1);

        engine.window.swapBuffers();
        glfw.pollEvents();
    }

    debug.log("Finished.", .{});
}
