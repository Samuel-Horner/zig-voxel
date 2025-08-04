#version 460 core

uniform mat4 view;
uniform mat4 proj;
uniform mat4 model;

layout(location = 0) in vec3 vertex_pos;

void main() {
    gl_Position = proj * view * model * vec4(vertex_pos, 1.);
}
