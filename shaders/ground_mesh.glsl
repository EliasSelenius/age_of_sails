
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

vec4 get_terrain() {
    float height_map_res = 42;

    float r = 1.0 / height_map_res;
    vec2 uv = r + a_Uv * (height_map_res - 2) / height_map_res;

    float g = 1.0 / (401);
    float h1 = texture(height_map, uv).x;
    float h2 = texture(height_map, uv + vec2(g, 0)).x;
    float h3 = texture(height_map, uv + vec2(0, g)).x;
    float h4 = texture(height_map, uv + vec2(-g, 0)).x;
    float h5 = texture(height_map, uv + vec2(0, -g)).x;

    float d = 1;
    vec3 p1 = vec3(0,  h1,  0);
    vec3 p2 = vec3(d,  h2,  0);
    vec3 p3 = vec3(0,  h3,  d);
    vec3 p4 = vec3(-d, h4,  0);
    vec3 p5 = vec3(0,  h5, -d);

    /*
        p3
    p4  p1  p2
        p5
    */

    vec3 normal = normalize(cross(p3 - p1, p2 - p1) +
                            cross(p4 - p1, p3 - p1) +
                            cross(p5 - p1, p4 - p1) +
                            cross(p2 - p1, p5 - p1));

    return vec4(normal, h1);
}

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

    FragColor = vec3(fract(v2f.height)) + vec3(v2f.uv, 0.0);
}

#endif