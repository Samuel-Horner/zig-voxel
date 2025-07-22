const std = @import("std");
const builtin = @import("builtin");

const glfw = @import("glfw");
const gl = @import("gl");
const zm = @import("zm");

const engine = @import("engine/engine.zig");
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

const vertices = [_]f32{
    -0.5, -0.5, 0.0,
     0.5, -0.5, 0.0,
     0.0,  0.5, 0.0 
};

fn testCallback(_: u32, _: u32) void {
    debug.log("WWWEAWEAW", .{});
}

pub fn main() !void {
    // ##### Debug Info #####
    // Zig version
    debug.log("Zig {s}.", .{
        builtin.zig_version_string
    });

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
    try engine.init(1200, 800, "JetBrainsMonoNerdFont-Regular.ttf",
        .{
            .force_wayland = args.force_wayland
        }
    );
    defer engine.deinit();

    // ##### Player Init #####
    try player.init(.{0, 0, -1}, 10, 0.05, 90);

    // ##### Hello Tzig array of function bodiesriangle #####
    // Gen Buffers
    var vbo: c_uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]);
    
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);

    gl.BindVertexArray(vao);

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);
    // Bind Buffers
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 3, 0);
    gl.EnableVertexAttribArray(0);

    // Create Program
    var program: engine.Program = try engine.Program.init(vertex_source, fragment_source);

    const view = gl.GetUniformLocation(program.id, "view");
    const proj = gl.GetUniformLocation(program.id, "proj");

    // ##### Timer Init #####
    var frame_timer = try std.time.Timer.start();

    // ##### Render Loop #####
    while (!engine.window.shouldClose()) {
        if (engine.keyPressed(engine.Key.escape)) {
            engine.window.setShouldClose(true);
        }

        // Time Methods
        const delta_time: f32 = @as(f32, @floatFromInt(frame_timer.lap())) / 1e9;

        // Player Tick
        player.tick(delta_time);

        // Render
        engine.clearViewport();

        program.use();
        gl.BindVertexArray(vao);

        gl.UniformMatrix4fv(view, 1, gl.FALSE, @ptrCast(&player.getView().data));
        gl.UniformMatrix4fv(proj, 1, gl.FALSE, @ptrCast(&player.getProj().data));

        gl.DrawArrays(gl.TRIANGLES, 0, 3);

        engine.window.swapBuffers();
        glfw.pollEvents();
    }

    debug.log("Finished.", .{});
}
