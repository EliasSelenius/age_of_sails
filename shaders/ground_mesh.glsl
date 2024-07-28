
IO FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
} v2f;

#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "shaders/ground.glsl"
#include "../grax/shaders/camera.glsl"

uniform vec2 chunk_pos;

layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

void main() {
    vec4 pos = vec4(a_Pos, 1.0);
    pos.xz += chunk_pos;
    // pos.y += noise(pos.xyz / 100.0) * 100;
    vec3 normal;
    pos.y = ground(pos.xz, normal);

    pos = camera.view * pos;
    v2f.pos = pos.xyz;
    // v2f.normal = mat3(camera.view) * a_Normal;
    v2f.normal = mat3(camera.view) * normal;
    v2f.uv = a_Uv;

    gl_Position = camera.projection * pos;
}

#endif
#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

layout (location = 0) out vec3 FragPos;
layout (location = 1) out vec3 FragNormal;
layout (location = 2) out vec3 FragColor;

void main() {
    FragPos = v2f.pos;
    FragNormal = normalize(v2f.normal);
    FragColor = vec3(1.0);
}

#endif