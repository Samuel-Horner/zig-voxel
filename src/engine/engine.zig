//! Engine file, contains OpenGL boilerplate methods and GLFW window operations
const std = @import("std");

const glfw = @import("glfw");
// Allows using gl functions with engine.gl
pub const gl = @import("gl");

const debug = @import("../debug.zig");
const text = @import("text.zig");

// Export types to avoid needing to seperately import glfw
pub const Key = glfw.Key;
pub const Window = glfw.Window;

pub var allocator: std.mem.Allocator = undefined;

pub var window: glfw.Window = undefined;

pub var window_width: u32 = undefined;
pub var window_height: u32 = undefined;

var procs: gl.ProcTable = undefined;

// ##### Callbacks #####
fn glfwErrorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    debug.err("GLFW: ({}) {s}", .{ error_code, description });
}

pub const SizeCallback = *const fn (u32, u32) void;
var size_callbacks: std.ArrayList(SizeCallback) = undefined;

pub fn registerFrameBufferSizeCallback(callback: SizeCallback) !void {
    try size_callbacks.append(callback);
    debug.log("Registered new frame buffer size callback.", .{});
}

fn glfwFrameBufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    window_width = width;
    window_height = height;
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
    debug.log("Window resized to {}x{}.", .{ width, height });

    for (size_callbacks.items) |callback| {
        callback(width, height);
    }
}

// ##### Init #####
pub fn init(width: u32, height: u32, comptime font_name: []const u8, engine_allocator: std.mem.Allocator, opts: struct { force_wayland: bool = false }) !void {
    allocator = engine_allocator;
    // ##### Initialise window #####
    window_width = width;
    window_height = height;

    glfw.setErrorCallback(glfwErrorCallback);

    if (opts.force_wayland) {
        debug.log("Attemping to force glfw to use native wayland.", .{});
    }

    if (!glfw.init(.{
        // Prefer native Wayland over XWayland
        .platform = if (opts.force_wayland) .wayland else .any,
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
    size_callbacks = std.ArrayList(SizeCallback).init(allocator);

    window.setFramebufferSizeCallback(glfwFrameBufferSizeCallback);

    debug.log("Created GLFW Context: {s}.", .{glfw.getVersionString()});

    glfw.makeContextCurrent(window);
    glfw.swapInterval(0); // Disables v-sync

    // ##### OpenGL Setup #####
    if (!procs.init(glfw.getProcAddress)) {
        return error.InitFailed;
    }

    gl.makeProcTableCurrent(&procs);
    debug.log("Loaded OpenGL {s} {}.{}.", .{ @tagName(gl.info.profile orelse "unkown"), gl.info.version_major, gl.info.version_minor });

    // OpenGL Settings
    gl.Viewport(0, 0, @intCast(window_width), @intCast(window_height));
    gl.ClearColor(0.43137254901960786, 0.6941176470588235, 1, 1);

    gl.Enable(gl.DEPTH_TEST);
    // gl.Enable(gl.CULL_FACE);

    debug.log("GPU: {?s}.", .{gl.GetString(gl.RENDERER)});

    // ##### Text Setup #####
    try text.init(font_name);
    // try registerFrameBufferSizeCallback(text.setFaceSize);
    try registerFrameBufferSizeCallback(text.updateTextProjection);
}

pub fn deinit() void {
    // Free Callback List
    size_callbacks.deinit();

    // Destroy FreeType Resources
    text.deinit();

    // Destroy OpenGL resources
    gl.makeProcTableCurrent(null);

    // Destroy GLFW resources
    window.destroy();
    glfw.terminate();
}

pub fn toggleFullScreen() void {
    if (window.getMonitor() == null) {
        const monitor = glfw.Monitor.getPrimary();
        const mode = monitor.?.getVideoMode();

        window.setMonitor(monitor, 0, 0, mode.?.getWidth(), mode.?.getHeight(), mode.?.getRefreshRate());
    } else {
        window.setMonitor(null, 0, 0, 1200, 800, 0);
    }
}

pub fn clearViewport() void {
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

pub fn keyPressed(key: glfw.Key) bool {
    return window.getKey(key) == glfw.Action.press;
}

// ##### VertexBuffer #####
pub const VertexBuffer = struct {
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,

    indices_len: c_int,

    pub fn draw(vertex_buffer: *VertexBuffer) void {
        gl.BindVertexArray(vertex_buffer.vao);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, vertex_buffer.ebo);

        gl.DrawElements(gl.TRIANGLES, vertex_buffer.indices_len, gl.UNSIGNED_INT, 0);
    }

    pub fn init(vertices: []const f32, indices: []const c_uint, comptime value_split: []const c_int, opts: struct { draw_mode: c_uint = gl.STATIC_DRAW }) VertexBuffer {
        var vertex_buffer: VertexBuffer = undefined;

        gl.GenVertexArrays(1, (&vertex_buffer.vao)[0..1]);
        gl.GenBuffers(1, (&vertex_buffer.vbo)[0..1]);
        gl.GenBuffers(1, (&vertex_buffer.ebo)[0..1]);

        gl.BindVertexArray(vertex_buffer.vao);

        gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer.vbo);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, vertex_buffer.ebo);

        gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(f32) * vertices.len), vertices.ptr, opts.draw_mode);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(c_uint) * indices.len), indices.ptr, opts.draw_mode);

        var stride: c_int = 0;
        for (value_split) |split| {
            stride += split * @sizeOf(f32);
        }

        var offset: usize = 0;
        for (value_split, 0..) |split, i| {
            gl.VertexAttribPointer(@intCast(i), split, gl.FLOAT, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(@intCast(i));
            offset += @intCast(split * @sizeOf(f32));
        }

        vertex_buffer.indices_len = @intCast(indices.len);

        return vertex_buffer;
    }
};

// ##### Uniform Struct #####
pub const UniformFunction = union {
    basic: *const fn (c_int) void,
    owned: *const fn (*anyopaque, c_int) void,
};

pub const Uniform = struct {
    location: c_int,
    function: UniformFunction,

    fn applyOwned(uniform: *const Uniform, owner: *anyopaque) void {
        uniform.function.owned(owner, uniform.location);
    }

    fn apply(uniform: *const Uniform) void {
        uniform.function.basic(uniform.location);
    }

    fn init(location: c_int, function: UniformFunction) Uniform {
        return Uniform{ .location = location, .function = function };
    }
};

// ##### Program Struct #####
pub const Program = struct {
    id: c_uint,

    uniforms: std.ArrayList(Uniform),

    fn compileShader(shader: c_uint, source: []const u8) !void {
        gl.ShaderSource(shader, 1, &.{source.ptr}, &.{@intCast(source.len)});
        gl.CompileShader(shader);

        var success: c_int = undefined;
        gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
        if (success != 1) {
            var info_log: [512:0]u8 = undefined;
            gl.GetShaderInfoLog(shader, info_log.len, null, &info_log);
            debug.err("Shader {} failed to compile.\n{s}", .{ shader, std.mem.sliceTo(&info_log, 0) });

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
            debug.err("Program {} failed to link.\n{s}", .{ program.id, std.mem.sliceTo(&info_log, 0) });

            return error.ProgramLinkFailed;
        }
    }

    pub fn init(vertex_source: []const u8, fragment_source: []const u8) !Program {
        var program: Program = undefined;

        // Vertex Shader
        const vertex_shader: c_uint = gl.CreateShader(gl.VERTEX_SHADER);
        try Program.compileShader(vertex_shader, vertex_source);

        // Fragment Shader
        const fragment_shader: c_uint = gl.CreateShader(gl.FRAGMENT_SHADER);
        try Program.compileShader(fragment_shader, fragment_source);

        // Create and link program
        program.id = gl.CreateProgram();
        try program.linkProgram(vertex_shader, fragment_shader);

        debug.log("Created program {}.", .{program.id});

        // Delete shaders
        gl.DeleteShader(vertex_shader);
        gl.DeleteShader(fragment_shader);

        // Setup Uniform List
        program.uniforms = std.ArrayList(Uniform).init(allocator);

        return program;
    }

    pub fn registerUniform(program: *Program, comptime name: [:0]const u8, function: UniformFunction) !usize {
        const location = gl.GetUniformLocation(program.id, name.ptr);

        if (location == -1) {
            debug.err("Failed to find uniform \"{s}\" in program {}.", .{ name, program.id });
            return error.UniformNotFound;
        }

        try program.uniforms.append(Uniform.init(location, function));

        return program.uniforms.items.len - 1;
    }

    pub fn use(program: *Program) void {
        gl.UseProgram(program.id);
    }

    pub fn applyAllUniforms(program: *Program) void {
        for (program.uniforms.items) |uniform| {
            uniform.apply();
        }
    }

    pub fn applyUniform(program: *Program, uniform: usize) void {
        program.uniforms.items[uniform].apply();
    }

    pub fn applyOwnedUniform(program: *Program, uniform: usize, owner: *anyopaque) void {
        program.uniforms.items[uniform].applyOwned(owner);
    }

    pub fn deinit(program: *Program) void {
        program.uniforms.deinit();
    }
};
