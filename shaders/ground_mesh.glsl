
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

    float h1 = texture(height_map, a_Uv).r;

    float d = 10;
    float h2 = texture(height_map, a_Uv + vec2(d, 0) / 400.0).r;
    float h3 = texture(height_map, a_Uv + vec2(0, d) / 400.0).r;
    float h4 = texture(height_map, a_Uv + vec2(-d, 0) / 400.0).r;
    float h5 = texture(height_map, a_Uv + vec2(0, -d) / 400.0).r;

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


    pos.y = h1;
    v2f.height = h1;



    pos = camera.view * pos;
    v2f.pos = pos.xyz;
    v2f.normal = mat3(camera.view) * normal;
    v2f.uv = a_Uv;


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