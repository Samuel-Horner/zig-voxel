const std = @import("std");

const freetype = @import("freetype");
const gl = @import("gl");
const zm = @import("zm");

const debug = @import("../debug.zig");
const engine = @import("engine.zig");

const text_fragment_source = @embedFile("../shader/text_frag.glsl");
const text_vertex_source = @embedFile("../shader/text_vert.glsl");

var ft: freetype.Library = undefined;
var ft_face: freetype.Face = undefined;

var chars: [128]Character = undefined;

var text_program: engine.Program = undefined;
var text_vertex_buffer: engine.VertexBuffer = undefined;

const Character = struct {
    texture_id: c_uint,
    width: f32,
    height: f32,
    top: f32,
    left: f32,
    advance: f32,
};

// ##### Text Projection #####
var text_projection_uniform: usize = undefined;
var text_projection: zm.Mat4f = undefined;

pub fn updateTextProjection(window_width: u32, window_height: u32) void {
    text_projection = zm.Mat4f.orthographic(0, @floatFromInt(window_width), @floatFromInt(window_height), 0, 0, 1).transpose();

    text_program.use();
    text_program.applyUniform(text_projection_uniform);
}

fn applyTextProjection(location: c_int) void {
    gl.UniformMatrix4fv(location, 1, gl.FALSE, @ptrCast(&text_projection.data));
}

// ##### FreeType #####
// pub fn setFaceSize(window_width: u32, window_height: u32) void {
//     ft_face.setCharSize(0, 16, @intCast(window_width), @intCast(window_height)) catch {
//         debug.err("Error setting FreeType face size. Window {}x{}.", .{ window_width, window_height });
//     };
// 
//     loadCharacters() catch {
//         debug.err("Error rebuilding character bitmaps for new window size {}x{}.", .{ window_width, window_height });
//     };
// }

pub fn setFaceSize(height: u32) !void {
    try ft_face.setPixelSizes(0, height);
}

fn loadCharacters() !void {
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);

    for (0..128) |c| {
        const char: u8 = @intCast(c);

        ft_face.loadChar(char, .{ .render = true }) catch |err| {
            debug.err("Failed to load character '{c}'.", .{char});
            return err;
        };

        if (ft_face.glyph().bitmap().buffer() == null) {
            if (std.ascii.isPrint(char) and char != ' ') {
                debug.err("Null bitmap buffer for character '{c}'.", .{char});
            }
            continue;
        }

        // Create texture on GPU
        var texture: c_uint = undefined;
        gl.GenTextures(1, (&texture)[0..1]);
        gl.BindTexture(gl.TEXTURE_2D, texture);
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            @intCast(ft_face.glyph().bitmap().width()),
            @intCast(ft_face.glyph().bitmap().rows()),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            ft_face.glyph().bitmap().buffer().?.ptr,
        );

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        chars[c].texture_id = texture;

        chars[c].width = @floatFromInt(ft_face.glyph().bitmap().width());
        chars[c].height = @floatFromInt(ft_face.glyph().bitmap().rows());

        chars[c].top = @floatFromInt(ft_face.glyph().bitmapTop());
        chars[c].left = @floatFromInt(ft_face.glyph().bitmapLeft());

        chars[c].advance = @as(f32, @floatFromInt(ft_face.glyph().advance().x)) / 64; // Convert to pixels
    }

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 0);
}


pub fn init(comptime font_name: []const u8) !void {
    // ##### Init FreeType #####
    ft = try freetype.Library.init();
    debug.log("Initiated FreeType v.{}.{}.{}.", .{ ft.version().major, ft.version().minor, ft.version().patch });

    // ##### Create Font Faces #####
    ft_face = try ft.createFaceMemory(@embedFile("../font/" ++ font_name), 0);

    try setFaceSize(128);

    // ##### Create Character Arrays #####
    try loadCharacters();
    debug.log("Created glyph bitmaps with font {s}.", .{font_name});

    // ##### Create Text Program #####
    text_program = try engine.Program.init(@embedFile("../shader/text_vert.glsl"), @embedFile("../shader/text_frag.glsl"));

    text_projection_uniform = try text_program.registerUniform("projection", .{.basic = applyTextProjection});
    updateTextProjection(engine.window_width, engine.window_height);

    // ##### Create Text Vertex Buffer #####
    // zig fmt: off
    text_vertex_buffer = engine.VertexBuffer.init(
        &([_]f32{0} ** 16),
        &.{2, 1, 0, 3, 2, 0},
        &.{4},
        .{.draw_mode = gl.DYNAMIC_DRAW}
    );
    // zig fmt: on
}

const DEFAULT_SCALE_MOD: f32 = 0.25;

pub fn renderText(text: []const u8, pos: zm.Vec2f, scale: f32) void {
    gl.Enable(gl.BLEND);
    defer gl.Disable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL);

    text_program.use();

    gl.ActiveTexture(gl.TEXTURE0);

    gl.BindVertexArray(text_vertex_buffer.vao);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, text_vertex_buffer.ebo);
    gl.BindBuffer(gl.ARRAY_BUFFER, text_vertex_buffer.vbo);

    var draw_pos = pos;

    const scale_mod = scale * DEFAULT_SCALE_MOD;

    for (text) |char| {
        if (char == '\n') {
            draw_pos[1] += (chars['H'].top + 16) * scale_mod;
            draw_pos[0] = pos[0];
            continue;
        }

        if (char == ' ') {
            draw_pos[0] += chars['_'].advance * scale_mod;
            continue;
        }

        const xpos: f32 = draw_pos[0] + chars[char].left * scale_mod;
        const ypos: f32 = draw_pos[1] + (chars['H'].top - chars[char].top) * scale_mod;

        const xoffset: f32 = xpos + (chars[char].width * scale_mod);
        const yoffset: f32 = ypos + (chars[char].height * scale_mod);

        // zig fmt: off
        const verts = [_]f32{
            xpos,    yoffset, 0, 1,
            xpos,    ypos,    0, 0,
            xoffset, ypos,    1, 0,
            xoffset, yoffset, 1, 1
        };
        // zig fmt: on

        gl.BufferSubData(gl.ARRAY_BUFFER, 0, @sizeOf(f32) * 16, &verts);
        gl.BindTexture(gl.TEXTURE_2D, chars[char].texture_id);

        gl.DrawElements(gl.TRIANGLES, text_vertex_buffer.indices_len, gl.UNSIGNED_INT, 0);

        draw_pos[0] += chars[char].advance * scale_mod;
    }
}

pub fn deinit() void {
    ft.deinit();
    text_program.deinit();
}
