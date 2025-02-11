
IO FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
    float height;
} v2f;

#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "../grax/shaders/noise.glsl"
#include "../grax/shaders/camera.glsl"

uniform vec2 chunk_pos;
uniform sampler2D height_map;

layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

#include "shaders/ground.glsl"

void main() {

    vec4 terrain = get_terrain();
    vec3 normal = terrain.xyz;
    float height = terrain.w;

    vec4 pos = vec4(a_Pos, 1.0);
    pos.xz += chunk_pos;
    pos.y = height;
    pos = camera.view * pos;

    v2f.pos = pos.xyz;
    v2f.normal = mat3(camera.view) * normal;
    v2f.uv = a_Uv;
    v2f.height = height;


    gl_Position = camera.projection * pos;
}

#endif
#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

layout (location = 0) out vec4 FragPos_Metallic;
layout (location = 1) out vec4 FragNormal_Roughness;
layout (location = 2) out vec3 FragColor;

void main() {
    FragPos_Metallic.xyz = v2f.pos;
    FragPos_Metallic.w   = 0;

    FragNormal_Roughness.xyz = normalize(v2f.normal);
    FragNormal_Roughness.w   = 0.9;

    float contour = 1.0 - step(0.01, fract(v2f.height));

    FragColor = vec3(contour) + vec3(v2f.uv, 0.0);
}

#endif