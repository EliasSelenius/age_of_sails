
IO FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
    float height;
} v2f;

#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "shaders/ground.glsl"
#include "../grax/shaders/camera.glsl"

uniform vec2 chunk_pos;
uniform sampler2D height_map;


layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

void main() {
    vec4 pos = vec4(a_Pos, 1.0);
    pos.xz += chunk_pos;

    vec3 normal = vec3(0, 1, 0);
    // float h = texelFetch(height_map, ivec2(pos.xz)+ivec2(0), 0).r;
    float region_size = 400.0;
    // float h = texture(height_map, (pos.xz + vec2(region_size / 2)) / region_size).r;
    float h = texture(height_map, a_Uv).r;

    pos.y = h;
    v2f.height = h;



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
    FragColor = vec3(fract(v2f.height)) + vec3(v2f.uv, 0.0);
}

#endif