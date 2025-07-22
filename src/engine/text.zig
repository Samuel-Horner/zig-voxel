const std = @import("std");

const freetype = @import("freetype");
const gl = @import("gl");

const debug = @import("../debug.zig");

const text_fragment_source = @embedFile("../shader/text_frag.glsl");
const text_vertex_source = @embedFile("../shader/text_vert.glsl");

var ft: freetype.Library = undefined;
var ft_face: freetype.Face = undefined;

var chars: [128]Character = undefined;

const Character = struct {
    texture_id: c_uint,
    
    width: u32,
    height: u32,

    top: i32,
    left: i32,

    advance: c_long
};

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
            ft_face.glyph().bitmap().buffer().?.ptr
        );

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        chars[c].texture_id = texture;

        chars[c].width = ft_face.glyph().bitmap().width();
        chars[c].height = ft_face.glyph().bitmap().rows();

        chars[c].top = ft_face.glyph().bitmapTop();
        chars[c].left = ft_face.glyph().bitmapLeft();

        chars[c].advance = ft_face.glyph().advance().x;
    }

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 0);
}

pub fn init(comptime font_name: []const u8, window_width: u32, window_height: u32) !void {
    ft = try freetype.Library.init();
    debug.log("Initiated FreeType v.{}.{}.{}.", .{ft.version().major, ft.version().minor, ft.version().patch});

    ft_face = try ft.createFaceMemory(@embedFile("../font/" ++ font_name), 0);

    setFaceSize(window_width, window_height);

    try loadCharacters();
    debug.log("Created glyph bitmaps with font {s}.", .{font_name});
}

pub fn deinit() void {
    ft.deinit();
}

pub fn setFaceSize(window_width: u32, window_height: u32) void {
    ft_face.setCharSize(0, 16, @intCast(window_width), @intCast(window_height)) catch {
        debug.err("Error setting FreeType face size. Window {}x{}.", .{window_width, window_height});
    };
}
