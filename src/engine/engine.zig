//! Engine file, contains OpenGL boilerplate methods and GLFW window operations
const std = @import("std");

const debug = @import("../debug.zig");

const glfw = @import("glfw");
const gl = @import("gl");

// Export types to avoid needing to seperately import glfw
pub const Key = glfw.Key;
pub const Window = glfw.Window;

pub var window: glfw.Window = undefined;

pub var window_width: u32 = undefined;
pub var window_height: u32 = undefined;

var procs: gl.ProcTable = undefined;

// ##### Callbacks #####
fn glfwErrorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    debug.err("GLFW: ({}) {s}", .{
        error_code,
        description
    });
}

pub const SizeCallback = fn (u32, u32) void;

var callback_gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var size_callbacks: std.ArrayList(SizeCallback) = undefined;

fn glfwFrameBufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    window_width = width;
    window_height = height;
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
    debug.log("Window resized to {}x{}.", .{
        width,
        height
    });

    for (size_callbacks.items) |callback| {
        callback(width, height);
    }
}

// fn glfwKeyCallback(_: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
//     _ = scancode;
//     _ = mods;
// 
//     if (action != glfw.Action.press) { return; }
// 
//     debug.log("{s}", .{
//         @tagName(key)
//     });
// }

pub fn init(width: u32, height: u32, frame_size_callbacks: []SizeCallback, opts: struct {force_wayland: bool = false}) !void {
    // ##### Initialise window #####
    window_width = width;
    window_height = height;

    glfw.setErrorCallback(glfwErrorCallback);

    if (opts.force_wayland) { debug.log("Attemping to force glfw to use native wayland.", .{}); }

    if (!glfw.init(.{
        // Prefer native Wayland over XWayland
        .platform = if (opts.force_wayland) .wayland else .any
    })) {
        return error.GlfwInitFailed;
    }

    // Window Hints
    window = glfw.Window.create(window_width, window_height, "zig-voxel", null, null, .{
        .context_version_major = 3,
        .context_version_minor = 3,
        .resizable = false,
    }) orelse {
        return error.WindowCreationFailed;
    };

    window.setInputModeCursor(glfw.Window.InputModeCursor.disabled);

    // ##### Callback Management #####
    callback_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    size_callbacks = std.ArrayList(SizeCallback).init(callback_gpa.allocator());

    try size_callbacks.appendSlice(frame_size_callbacks);

    window.setFramebufferSizeCallback(glfwFrameBufferSizeCallback);
    
    debug.log("Created GLFW Context: {s}.", .{
        glfw.getVersionString() 
    });

    glfw.makeContextCurrent(window);
    glfw.swapInterval(0); // Disables v-sync
    
    // ##### OpenGL Setup #####
    if (!procs.init(glfw.getProcAddress)) { 
        return error.InitFailed;
    }

    gl.makeProcTableCurrent(&procs);
    debug.log("Loaded OpenGL {s} {}.{}.", .{
        @tagName(gl.info.profile orelse "unkown"),
        gl.info.version_major,
        gl.info.version_minor
    });

    // OpenGL Settings
    gl.Viewport(0, 0, @intCast(window_width), @intCast(window_height));
    gl.ClearColor(0.43137254901960786, 0.6941176470588235, 1, 1);

    gl.Enable(gl.DEPTH_TEST);
    //gl.Enable(gl.CULL_FACE);

    debug.log("GPU: {?s}.", .{
        gl.GetString(gl.RENDERER)
    });
}

pub fn destroy() void {
    // Free Callback Allocators
    size_callbacks.deinit();
    callback_gpa.deinit();

    // Destroy OpenGL resources
    gl.makeProcTableCurrent(null);

    // Destroy GLFW resources
    window.destroy();
    glfw.terminate();
}

pub fn clearViewport() void {
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

pub fn keyPressed(key: glfw.Key) bool {
    return window.getKey(key) == glfw.Action.press;
}

// ##### Program Struct #####
pub const Program = struct {
    id: c_uint,

    fn compileShader(shader: c_uint, source: []const u8) !void {
        gl.ShaderSource(
            shader,
            1,
            &.{source.ptr},
            &.{@intCast(source.len)}
        );
        gl.CompileShader(shader);

        var success: c_int = undefined; 
        gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
        if (success != 1) {
            var info_log: [512:0]u8 = undefined;
            gl.GetShaderInfoLog(shader, info_log.len, null, &info_log);
            debug.err("Shader {} failed to compile.\n{s}", .{
                shader, 
                std.mem.sliceTo(&info_log, 0)}
            );

            return error.ShaderCompilationFailed;
        }
    }

    fn linkProgram(program: *Program, vertex_shader: c_uint, fragment_shader: c_uint) !void {
        gl.AttachShader(program.id, vertex_shader);
        gl.AttachShader(program.id, fragment_shader);

        gl.LinkProgram(program.id);

        // Check program link status
        var success: c_int = undefined; 
        gl.GetProgramiv(program.id, gl.LINK_STATUS, &success);
        if (success != 1) {
            var info_log: [512:0]u8 = undefined;
            gl.GetProgramInfoLog(program.id, info_log.len, null, &info_log);
            debug.err("Program {} failed to link.\n{s}", .{
                program.id, 
                std.mem.sliceTo(&info_log, 0)}
            );

            return error.ProgramLinkFailed;
        }
    }

    pub fn init(vertex_source: []const u8, fragment_source: []const u8) !Program {
        var program: Program = .{.id = undefined};

        // Vertex Shader
        const vertex_shader: c_uint = gl.CreateShader(gl.VERTEX_SHADER);
        try Program.compileShader(vertex_shader, vertex_source);

        // Fragment Shader
        const fragment_shader: c_uint = gl.CreateShader(gl.FRAGMENT_SHADER);
        try Program.compileShader(fragment_shader, fragment_source);        

        // Create and link program
        program.id = gl.CreateProgram();
        try program.linkProgram(vertex_shader, fragment_shader);

        debug.log("Created program {}.", .{
            program.id
        });

        // Delete shaders
        gl.DeleteShader(vertex_shader);
        gl.DeleteShader(fragment_shader);

        return program;
    } 

    pub fn use(program: *Program) void {
        gl.UseProgram(program.id);
    }
};
