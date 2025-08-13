const std = @import("std");

const zm = @import("zm");
const znoise = @import("znoise");

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

var seed: i32 = undefined;
var height: u32 = undefined;

var gen: znoise.FnlGenerator = undefined;

pub fn init(allocator: std.mem.Allocator, world_seed: i32, world_height: u32) !void {
    world_allocator = allocator;

    // Chunk Program init
    chunk_program = try engine.Program.init(@embedFile("shader/chunk_vert.glsl"), @embedFile("shader/chunk_frag.glsl"));
    model_uniform = try chunk_program.registerUniform("model", .{ .owned = Chunk.applyModel });
    view_uniform = try chunk_program.registerUniform("view", .{ .basic = player.applyView });
    projection_uniform = try chunk_program.registerUniform("proj", .{ .basic = player.applyProj });

    // Chunk Map Init
    chunk_map = ChunkMap.init(world_allocator);

    seed = world_seed;
    height = world_height;

    // Noise initialisation
    gen = znoise.FnlGenerator{
        .seed = world_seed,
        .frequency = 0.01
    };
}

pub fn deinit() void {
    chunk_map.deinit();
    chunk_program.deinit();
}

fn populateChunk(pos: zm.vec.Vec(3, i32)) [CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]u32 {
    var chunk_voxels: [CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]u32 = undefined;

    const chunk_world_pos: zm.vec.Vec(3, i32) = zm.vec.scale(pos, CHUNK_SIZE);
    // const chunk_world_column: zm.vec.Vec(2, i32) = zm.vec.Vec(2, i32){ chunk_world_pos[0], chunk_world_pos[2] };

    // for (0..CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE) |index| {
    //     // chunk_voxels[index] = @intCast(index % 2);
    //     // chunk_voxels[index] = voxels.solid;
    // }

    // for (0..CHUNK_SIZE) |x| {
    //     for (0..CHUNK_SIZE) |z| {
    //         const voxel_column = chunk_world_column + zm.vec.Vec(2, i32){ @intCast(x), @intCast(z) };
    //
    //         // const height_value: i32 = @intFromFloat(noise.noise2iVec(seed, voxel_column, 0) * @as(f32, @floatFromInt(height)));
    //         const height_value: i32 = @intFromFloat(
    //             gen.noise2(
    //                 @as(f32, @floatFromInt(voxel_column[0])),
    //                 @as(f32, @floatFromInt(voxel_column[1])),
    //             ) * @as(f32, @floatFromInt(height)),
    //         );
    //
    //         for (0..CHUNK_SIZE) |y| {
    //             const voxel_index: usize = Chunk.getVoxelIndex(x, y, z);
    //             const voxel_height: i32 = chunk_world_pos[0] + @as(i32, @intCast(y));
    //
    //             if (voxel_height < height_value) {
    //                 chunk_voxels[voxel_index] = voxels.solid;
    //             } else {
    //                 chunk_voxels[voxel_index] = voxels.empty;
    //             }
    //         }
    //     }
    // }

    for (0..CHUNK_SIZE) |x| {
        for (0..CHUNK_SIZE) |y| {
            for (0..CHUNK_SIZE) |z| {
                const voxel_pos = zm.vec.Vec(3, i32){ @intCast(x), @intCast(y), @intCast(z) } + chunk_world_pos;

                const index = Chunk.getVoxelIndex(x, y, z);

                const cutoff = gen.noise3(
                    @floatFromInt(voxel_pos[0]),
                    @floatFromInt(voxel_pos[1]),
                    @floatFromInt(voxel_pos[2]),
                );

                if (cutoff < 0) {
                    chunk_voxels[index] = voxels.empty;
                } else {
                    chunk_voxels[index] = voxels.solid;
                }
            }
        }
    }

    return chunk_voxels;
}

pub fn meshChunk(pos: zm.vec.Vec(3, i32)) !void {
    try getChunk(pos).?.mesh();
}

// Returns a NON-MESHED chunk
pub fn loadChunk(pos: zm.vec.Vec(3, i32)) !void {
    const loaded_chunk = getChunk(pos);
    if (loaded_chunk != null) {
        if (std.meta.eql(loaded_chunk.?.pos, pos)) {
            return;
        }
    }

    try chunk_map.put(pos, try Chunk.init(pos, populateChunk(pos)));
}

pub fn populateAndMeshWorld(render_distance: usize) !void {
    for (0..render_distance * 2) |x| {
        for (0..height) |y| {
            for (0..render_distance * 2) |z| {
                try loadChunk(.{
                    @as(i32, @intCast(x)) - @as(i32, @intCast(render_distance)),
                    @intCast(y),
                    @as(i32, @intCast(z)) - @as(i32, @intCast(render_distance)),
                });
            }
        }
    }

    var iter = chunk_map.valueIterator();

    while (iter.next()) |chunk| {
        try chunk.mesh();
    }
}

pub fn getChunk(pos: zm.vec.Vec(3, i32)) ?*Chunk {
    return chunk_map.getPtr(pos);
}

fn getVoxel(pos: zm.vec.Vec(3, i32)) u32 {
    const chunk_pos: zm.vec.Vec(3, i32) = .{
        @divFloor(pos[0], CHUNK_SIZE),
        @divFloor(pos[1], CHUNK_SIZE),
        @divFloor(pos[2], CHUNK_SIZE),
    };

    const chunk = getChunk(chunk_pos);
    if (chunk == null) {
        return voxels.empty;
    }

    const pos_in_chunk: zm.vec.Vec(3, usize) = .{
        @intCast(@mod(pos[0], CHUNK_SIZE)),
        @intCast(@mod(pos[1], CHUNK_SIZE)),
        @intCast(@mod(pos[2], CHUNK_SIZE)),
    };

    return chunk.?.voxels[
        Chunk.getVoxelIndex(
            pos_in_chunk[0],
            pos_in_chunk[1],
            pos_in_chunk[2],
        )
    ];
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
    ssbo: ?engine.SSBO,

    fn init(pos: zm.vec.Vec(3, i32), chunk_voxels: [CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]u32) !Chunk {
        var chunk: Chunk = undefined;

        chunk.pos = pos;
        chunk.voxels = chunk_voxels;
        chunk.ssbo = null;

        chunk.model = zm.Mat4f.translation(
            @floatFromInt(pos[0] * CHUNK_SIZE),
            @floatFromInt(pos[1] * CHUNK_SIZE),
            @floatFromInt(pos[2] * CHUNK_SIZE),
        ).transpose();

        return chunk;
    }

    fn getVoxelIndex(x: usize, y: usize, z: usize) usize {
        return x * CHUNK_SIZE * CHUNK_SIZE + y * CHUNK_SIZE + z;
    }

    fn getOffsetIndex(index: usize, x_offset: isize, y_offset: isize, z_offset: isize) usize {
        return @intCast(
            @as(isize, @intCast(index)) + (x_offset * CHUNK_SIZE * CHUNK_SIZE + y_offset * CHUNK_SIZE + z_offset),
        );
    }

    fn getNeighbours(chunk: *Chunk, index: usize, x: usize, y: usize, z: usize, voxel_pos: zm.vec.Vec(3, i32)) [6]bool {
        var neighbours = [_]bool{false} ** 6;
        // Face table:
        // 0 : x+
        // 1 : x-
        // 2 : y+
        // 3 : y-
        // 4 : z+
        // 5 : z-

        // x+
        if (x < CHUNK_SIZE - 1) {
            neighbours[0] = voxels.isOpaque(chunk.voxels[getOffsetIndex(index, 1, 0, 0)]);
        } else {
            neighbours[0] = voxels.isOpaque(getVoxel(.{ voxel_pos[0] + 1, voxel_pos[1], voxel_pos[2] }));
        }
        // x-
        if (x > 0) {
            neighbours[1] = voxels.isOpaque(chunk.voxels[getOffsetIndex(index, -1, 0, 0)]);
        } else {
            neighbours[1] = voxels.isOpaque(getVoxel(.{ voxel_pos[0] - 1, voxel_pos[1], voxel_pos[2] }));
        }
        // y+
        if (y < CHUNK_SIZE - 1) {
            neighbours[2] = voxels.isOpaque(chunk.voxels[getOffsetIndex(index, 0, 1, 0)]);
        } else {
            neighbours[2] = voxels.isOpaque(getVoxel(.{ voxel_pos[0], voxel_pos[1] + 1, voxel_pos[2] }));
        }
        // y-
        if (y > 0) {
            neighbours[3] = voxels.isOpaque(chunk.voxels[getOffsetIndex(index, 0, -1, 0)]);
        } else {
            neighbours[3] = voxels.isOpaque(getVoxel(.{ voxel_pos[0], voxel_pos[1] - 1, voxel_pos[2] }));
        }
        // z+
        if (z < CHUNK_SIZE - 1) {
            neighbours[4] = voxels.isOpaque(chunk.voxels[getOffsetIndex(index, 0, 0, 1)]);
        } else {
            neighbours[4] = voxels.isOpaque(getVoxel(.{ voxel_pos[0], voxel_pos[1], voxel_pos[2] + 1 }));
        }
        // z-
        if (z > 0) {
            neighbours[5] = voxels.isOpaque(chunk.voxels[getOffsetIndex(index, 0, 0, -1)]);
        } else {
            neighbours[5] = voxels.isOpaque(getVoxel(.{ voxel_pos[0], voxel_pos[1], voxel_pos[2] - 1 }));
        }

        return neighbours;
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
                        continue;
                    }

                    const voxel_world_pos: zm.vec.Vec(3, i32) = .{
                        @as(i32, @intCast(x)) + chunk.pos[0] * CHUNK_SIZE,
                        @as(i32, @intCast(y)) + chunk.pos[1] * CHUNK_SIZE,
                        @as(i32, @intCast(z)) + chunk.pos[2] * CHUNK_SIZE,
                    };

                    const neighbours = getNeighbours(chunk, index, x, y, z, voxel_world_pos);

                    for (0..6) |face| {
                        if (neighbours[face]) {
                            continue;
                        }

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
        if (chunk.ssbo == null) {
            debug.err("Attempted to render non-meshed chunk {any}", .{chunk.pos});
            return;
        }
        chunk_program.applyOwnedUniform(model_uniform, chunk);
        chunk.ssbo.?.draw(0, @intCast(chunk.ssbo.?.length * VERTS_PER_FACE));
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
