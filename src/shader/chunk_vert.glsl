#version 460 core

uniform mat4 view;
uniform mat4 proj;
uniform mat4 model;

#define VERTS_PER_FACE 6

// struct Face {
//     uint x : 4;
//     uint y : 4;
//     uint z : 4;
//     uint _ : 20;
// }

layout(std430, binding = 0) readonly buffer FaceSSBO {
    uint faces[];
};

// Face table:
// 0 : x+
// 1 : x-
// 2 : y+
// 3 : y-
// 4 : z+
// 5 : z-

const vec3 vert_offsets[8] = vec3[8](
        vec3(1., 1., 1.), 
        vec3(1., 0., 1.), 
        vec3(0., 0., 1.), 
        vec3(0., 1., 1.), 
        vec3(1., 1., 0.), 
        vec3(1., 0., 0.), 
        vec3(0., 0., 0.), 
        vec3(0., 1., 0.)
    );

const uint face_indices[36] = {
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

const float voxel_tints[6] = {
    0.95, // X+
    0.95, // X-
    1.0, // Y+
    0.8, // Y-
    0.9, // Z+
    0.9  // Z-
};

out vec3 vert_color;

void main() {
    const uint face_index = gl_VertexID / VERTS_PER_FACE;

    const uint face_data = faces[face_index];
    const vec3 face_pos = vec3(
            (face_data) & 0xF,
            (face_data >> 4) & 0xF,
            (face_data >> 8) & 0xF
        );

    const vec3 col = vec3(
            (face_data >> 12) & 0xF,
            (face_data >> 16) & 0xF,
            (face_data >> 20) & 0xF
        ) / 16.;

    const uint face_id = (face_data >> 24) & 0x7;

    const uint vert_offset_index = face_indices[(gl_VertexID % VERTS_PER_FACE) + (face_id * VERTS_PER_FACE)];

    const vec3 vert_pos = face_pos + vert_offsets[vert_offset_index];

    gl_Position = proj * view * model * vec4(vert_pos, 1.);
    vert_color = col * voxel_tints[face_id];
}
