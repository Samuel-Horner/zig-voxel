#version 460 core

out vec4 FragColor;

in vec4 gl_FragCoord;
in vec3 VertexColor;
// in vec3 VertexNormal;
in float FaceTint;

const vec3 SunDir = normalize(vec3(-1, -2, -3));

void main() {
    // float light_intensity = max(0.5, dot(SunDir, VertexNormal));

    // FragColor = vec4(VertexColor.xyz, 1.) * light_intensity;
    // FragColor = vec4(VertexNormal.xyz, 1);
    // FragColor = vec4(vec3(light_intensity), 1);
    FragColor = vec4(VertexColor.xyz, 1.) * FaceTint;
}
