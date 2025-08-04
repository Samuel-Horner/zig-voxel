const std = @import("std");

const zm = @import("zm");

const engine = @import("engine/engine.zig");
const debug = @import("debug.zig");
const player = @import("player.zig");
const voxels = @import("voxels.zig");

const CHUNK_SIZE = 16;

const ChunkMap = std.AutoHashMap(zm.vec.Vec(3, i32), Chunk);
var chunk_map: ChunkMap = undefined;

var chunk_program: engine.Program = undefined;
var model_uniform: usize = undefined;
var view_uniform: usize = undefined;
var projection_uniform: usize = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    // Chunk Program init
    chunk_program = try engine.Program.init(@embedFile("shader/chunk_vert.glsl"), @embedFile("shader/chunk_frag.glsl"));
    model_uniform = try chunk_program.registerUniform("model", .{ .owned = Chunk.applyModel });
    view_uniform = try chunk_program.registerUniform("view", .{ .basic = player.applyView });
    projection_uniform = try chunk_program.registerUniform("proj", .{ .basic = player.applyProj });

    // Chunk Map Init
    chunk_map = ChunkMap.init(allocator);
}

pub fn deinint() void {
    chunk_map.deinit();
    chunk_program.deinit();
}

pub fn loadChunk(pos: zm.vec.Vec(3, i32)) !void {
    const loaded_chunk = getChunk(pos);
    if (loaded_chunk != null) {
        if (std.meta.eql(loaded_chunk.?.pos, pos)) {
            return;
        }
    }

    try chunk_map.put(pos, Chunk.init(pos, [_]u32{0} ** 4096));
}

fn getChunk(pos: zm.vec.Vec(3, i32)) ?Chunk {
    return chunk_map.get(pos);
}

pub fn render() void {
    chunk_program.use();
    chunk_program.applyUniform(view_uniform);
    chunk_program.applyUniform(projection_uniform);

    var iter = chunk_map.valueIterator();

    while (iter.next()) |chunk| {
        chunk.render();
    }
}

pub const Chunk = struct {
    pos: zm.vec.Vec(3, i32),
    voxels: [CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]u32,

    model: zm.Mat4f,
    vertex_buffer: engine.VertexBuffer,

    fn init(pos: zm.vec.Vec(3, i32), chunk_voxels: [CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]u32) Chunk {
        var chunk: Chunk = undefined;

        chunk.voxels = chunk_voxels;

        chunk.model = zm.Mat4f.translation(
            @floatFromInt(pos[0]),
            @floatFromInt(pos[1]),
            @floatFromInt(pos[2]),
        ).scale(CHUNK_SIZE).transpose();

        chunk.mesh();

        return chunk;
    }

    inline fn getVoxelIndex(x: usize, y: usize, z: usize) usize {
        return x * CHUNK_SIZE * CHUNK_SIZE + y * CHUNK_SIZE + z;
    }

    fn mesh(chunk: *Chunk) void {
        // for (0..CHUNK_SIZE) |x| {
        //     for (0..CHUNK_SIZE) |y| {
        //         for (0..CHUNK_SIZE) |z| {
        //             const index = Chunk.getVoxelIndex(x, y, z);
        //
        //             const voxel = chunk.voxels[index];
        //             if (!voxels.isOpaque(voxel)) { return; }
        //         }
        //     }
        // }

        const vertices = [_]f32{ -0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0 };
        const indicies = [_]c_uint{ 0, 1, 2 };

        chunk.vertex_buffer = engine.VertexBuffer.init(vertices[0..], indicies[0..], &.{3}, .{});
    }

    fn render(chunk: *Chunk) void {
        chunk_program.applyOwnedUniform(model_uniform, chunk);
        chunk.vertex_buffer.draw();
    }

    fn applyModel(chunk: *anyopaque, location: c_int) void {
        const chunk_ptr: *Chunk = @ptrCast(@alignCast(chunk));

        engine.gl.UniformMatrix4fv(
            location,
            1,
            engine.gl.FALSE,
            @ptrCast(&chunk_ptr.model.data),
        );
    }
};
