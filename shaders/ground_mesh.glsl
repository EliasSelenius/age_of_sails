
IO FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
    float height;
} v2f;

#include "../grax/shaders/noise.glsl"

#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "../grax/shaders/camera.glsl"
#include "shaders/ground.glsl"

uniform vec2 chunk_pos;
uniform sampler2D height_map;

layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;


void main() {

    vec4 terrain = get_terrain(height_map, a_Uv);
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


#ifdef TessControl //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (vertices = 4) out;

in vec2 in_uvs[];
out vec2 out_uvs[];

void main() {
    int id = gl_InvocationID;
    gl_out[id].gl_Position = gl_in[id].gl_Position;
    out_uvs[id] = in_uvs[id];

    gl_TessLevelOuter[0] = 1;
    gl_TessLevelOuter[1] = 1;
    gl_TessLevelOuter[2] = 1;
    gl_TessLevelOuter[3] = 1;

    gl_TessLevelInner[0] = 1;
    gl_TessLevelInner[1] = 1;
}
#endif


#ifdef TessEval /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (quads, equal_spacing, ccw) in;

in vec2 in_uvs[];
out vec2 out_uv;

void main() {
    gl_TessCoord;
}
#endif


#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

layout (location = 0) out vec4 FragPos_Metallic;
layout (location = 1) out vec4 FragNormal_Roughness;
layout (location = 2) out vec3 FragColor;

uniform vec3 u_color_additive = vec3(1.0);

void main() {
    FragPos_Metallic.xyz = v2f.pos;
    FragPos_Metallic.w   = 0;

    FragNormal_Roughness.xyz = normalize(v2f.normal);
    FragNormal_Roughness.w   = 0.9;

    float contour = 1.0 - step(0.01, fract(v2f.height));
    FragColor = vec3(0.0); //vec3(contour);// + vec3(v2f.uv, 0.0);

    FragColor += u_color_additive;
}
#endif