const std = @import("std");

const zm = @import("zm");

const engine = @import("engine/engine.zig");
const debug = @import("debug.zig");
const player = @import("player.zig");
const voxels = @import("voxels.zig");

const CHUNK_SIZE = 16;
const VERTS_PER_FACE = 6;

const ChunkMap = std.AutoHashMap(zm.vec.Vec(3, i32), Chunk);

var world_allocator: std.mem.Allocator = undefined;

var chunk_map: ChunkMap = undefined;

var chunk_program: engine.Program = undefined;
var model_uniform: usize = undefined;
var view_uniform: usize = undefined;
var projection_uniform: usize = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    world_allocator = allocator;

    // Chunk Program init
    chunk_program = try engine.Program.init(@embedFile("shader/chunk_vert.glsl"), @embedFile("shader/chunk_frag.glsl"));
    model_uniform = try chunk_program.registerUniform("model", .{ .owned = Chunk.applyModel });
    view_uniform = try chunk_program.registerUniform("view", .{ .basic = player.applyView });
    projection_uniform = try chunk_program.registerUniform("proj", .{ .basic = player.applyProj });

    // Chunk Map Init
    chunk_map = ChunkMap.init(world_allocator);
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

    try chunk_map.put(pos, try Chunk.init(pos, [_]u32{1} ** 4096));
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

// ##### Face #####
const Face = packed struct {
    x: u4,
    y: u4,
    z: u4,
    r: u4,
    g: u4,
    b: u4,
    face_id: u3,
    flags: u5,
};

// ##### Chunk #####
pub const Chunk = struct {
    pos: zm.vec.Vec(3, i32),
    voxels: [CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]u32,

    model: zm.Mat4f,
    ssbo: engine.SSBO,

    fn init(pos: zm.vec.Vec(3, i32), chunk_voxels: [CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]u32) !Chunk {
        var chunk: Chunk = undefined;

        chunk.voxels = chunk_voxels;

        chunk.model = zm.Mat4f.translation(
            @floatFromInt(pos[0] * CHUNK_SIZE),
            @floatFromInt(pos[1] * CHUNK_SIZE),
            @floatFromInt(pos[2] * CHUNK_SIZE),
        ).transpose();

        try chunk.mesh();

        return chunk;
    }

    inline fn getVoxelIndex(x: usize, y: usize, z: usize) usize {
        return x * CHUNK_SIZE * CHUNK_SIZE + y * CHUNK_SIZE + z;
    }

    fn mesh(chunk: *Chunk) !void {
        var faces = std.ArrayList(Face).init(world_allocator);
        defer faces.deinit();

        for (0..CHUNK_SIZE) |x| {
            for (0..CHUNK_SIZE) |y| {
                for (0..CHUNK_SIZE) |z| {
                    const index = Chunk.getVoxelIndex(x, y, z);

                    const voxel = chunk.voxels[index];
                    if (!voxels.isOpaque(voxel)) {
                        return;
                    }

                    for (0..6) |face| {
                        try faces.append(.{
                            .x = @intCast(x),
                            .y = @intCast(y),
                            .z = @intCast(z),
                            .r = @intCast(x),
                            .g = @intCast(y),
                            .b = @intCast(z),
                            .face_id = @intCast(face),
                            .flags = 0,
                        });
                    }
                }
            }
        }

        chunk.ssbo = engine.SSBO.init(Face, faces.items);
    }

    fn render(chunk: *Chunk) void {
        chunk_program.applyOwnedUniform(model_uniform, chunk);
        chunk.ssbo.draw(0, @intCast(chunk.ssbo.length * VERTS_PER_FACE));
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
