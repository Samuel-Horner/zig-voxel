#version 460 core

// struct VoxelData {
//     float voxel_pos[3]; // Using arrays instead of vectors to tightly pack data.
//     float voxel_col[3];
// };
#define VERTEX_PULLING_SCALE 6

// struct VoxelData {
//     uint x : 4;
//     uint y : 4;
//     uint z : 4;
//     uint r : 4;
//     uint g : 4;
//     uint b : 4;
//     uint face_id : 3;
//     uint flags : 5;
// };

// Face table:
// 0 : x+
// 1 : x-
// 2 : y+
// 3 : y-
// 4 : z+
// 5 : z-

layout (std430, binding = 0) readonly buffer VoxelSSBO {
    // VoxelData voxels[];
    uint voxels[];
};

const vec3 vert_positions[8] = vec3[8](
    vec3(1., 1., 1.), // 0
    vec3(1., 0., 1.), // 1
    vec3(0., 0., 1.), // 2
    vec3(0., 1., 1.), // 3
    vec3(1., 1., 0.), // 4
    vec3(1., 0., 0.), // 5
    vec3(0., 0., 0.), // 6
    vec3(0., 1., 0.)  // 7
);


const int voxel_indices[36] = {
    0, 5, 4, // X+
    0, 1, 5, 
    7, 6, 3, // X-
    6, 2, 3, 
    0, 4, 7, // Y+
    3, 0, 7, 
    6, 5, 1, // Y-
    6, 1, 2, 
    3, 1, 0, // Z+
    3, 2, 1, 
    4, 5, 7, // Z-
    5, 6, 7
};

// const vec3 voxel_normals[6] = {
//     vec3( 1, 0, 0),
//     vec3(-1, 0, 0),
//     vec3( 0, 1, 0),
//     vec3( 0,-1, 0),
//     vec3( 0, 0, 1),
//     vec3( 0, 0,-1)
// };

const float voxel_tints[6] = {
    0.95, // X+
    0.95, // X-
    1.0, // Y+
    0.8, // Y-
    0.9, // Z+
    0.9  // Z-
};

out vec3 VertexColor;
// out vec3 VertexNormal;
out float FaceTint;

layout (std140) uniform CamBlock {
    mat4 view;
    mat4 projection;
};

uniform mat4 model;
uniform uint lod_scale;

void main(){
    uint voxel_index = gl_VertexID / VERTEX_PULLING_SCALE;
    uint data = voxels[voxel_index];
    uint x = (data) & 0xF;
    uint y = (data >> 4) & 0xF;
    uint z = (data >> 8) & 0xF;
    vec3 pos = vec3(x, y, z);

    uint r = (data >> 12) & 0xF;
    uint g = (data >> 16) & 0xF;
    uint b = (data >> 20) & 0xF;
    vec3 col = vec3(r, g, b) / 16.;

    uint face_id = (data >> 24) & 0x7;

    uint vert_offset = gl_VertexID % VERTEX_PULLING_SCALE;

    uint indices_index = vert_offset + (face_id * 6);
    uint index = voxel_indices[indices_index];
    pos += vert_positions[index] * lod_scale;

    gl_Position = projection * view * model * vec4(pos, 1.0);
    VertexColor = col;
    // VertexNormal = voxel_normals[indices_index / 6];
    FaceTint = voxel_tints[indices_index / 6];
}
