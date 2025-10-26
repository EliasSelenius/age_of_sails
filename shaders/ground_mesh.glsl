
#extension GL_ARB_bindless_texture : require

IO FragData {
    vec3 pos;
    vec3 normal;
    vec3 view_pos;
    vec3 view_normal;
    vec2 uv;
    float height;
} v2f;

#include "../grax/shaders/noise.glsl"

uniform vec2 chunk_pos;
uniform vec4 u_color_tint = vec4(0.0);

layout (binding = 0) uniform sampler2D height_map;
layout (binding = 1) uniform sampler2D texture_albedo_sand;
layout (binding = 2) uniform sampler2D texture_albedo_grass;
layout (binding = 3) uniform sampler2D texture_albedo_cliff;


#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "../grax/shaders/camera.glsl"
#include "shaders/ground.glsl"

layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

vec4 noise_test(vec2 coord) {

    float h = 0;
    vec2 grad = vec2(0.0);
    for (int i = 1; i <= 4; i++) {
        float f = 1000.0 / float(i);
        float a = 500.0 / float(i);

        vec3 n = noised2(coord / f);
        h += a*n.z;
        grad += (a/f)*n.xy;
    }

    vec3 norm = normalize(vec3(-grad.x, 1, -grad.y));
    return vec4(norm, h);




    // float f0 = 1000.0;
    // float f1 = 100.0;

    // vec2 q0 = coord / f0;
    // vec2 q1 = coord / f1;
    // float a0 = 300;
    // float a1 = 90;

    // vec3 n0 = noised2(q0);
    // vec3 n1 = noised2(q1);

    // float h = a0*n0.z + a1*n1.z;
    // vec2 grad = (a0/f0)*n0.xy + (a1/f1)*n1.xy;

    // vec3 norm = normalize(vec3(-grad.x, 1, -grad.y));
    // return vec4(norm, h);
}

void main() {

    vec4 terrain = get_terrain(height_map, a_Uv);
    vec3 normal = terrain.xyz;
    float height = terrain.w;

    vec4 pos = vec4(a_Pos, 1.0) + vec4(chunk_pos.x, height, chunk_pos.y, 0);

    vec4 n = noise_test(pos.xz);
    pos.y = n.w;
    normal = n.xyz;

    vec4 view_pos = camera.view * pos;
    vec3 view_normal = mat3(camera.view) * normal;

    v2f.pos = pos.xyz;
    v2f.normal = normal;
    v2f.view_pos = view_pos.xyz;
    v2f.view_normal = view_normal;
    v2f.uv = a_Uv;
    v2f.height = n.w; // height;

    gl_Position = camera.projection * view_pos;
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


void main() {
    FragPos_Metallic.xyz = v2f.view_pos;
    FragPos_Metallic.w   = 0;

    vec3 normal = normalize(v2f.normal);
    vec3 view_normal = normalize(v2f.view_normal);
    FragNormal_Roughness.xyz = view_normal;
    FragNormal_Roughness.w   = 0.9;

    sampler2D texture_albedo;

    if (v2f.height < 10) {
        texture_albedo = texture_albedo_sand;
    } else {
        texture_albedo = texture_albedo_grass;
    }

    vec2 cliff_uv_x = vec2(v2f.pos.x, v2f.pos.y) / 100.0;
    vec2 cliff_uv_z = vec2(v2f.pos.z, v2f.pos.y) / 100.0;
    vec3 cliff_albedo_x = texture(texture_albedo_cliff, cliff_uv_x).rgb;
    vec3 cliff_albedo_z = texture(texture_albedo_cliff, cliff_uv_z).rgb;
    float t_x = abs(dot(vec3(1,0,0), normal));
    float t_z = abs(dot(vec3(0,0,1), normal));


    vec3 cliff_albedo = cliff_albedo_x*t_x + cliff_albedo_z*t_z;

    vec3 ground_albedo = texture(texture_albedo, v2f.uv).rgb;
    float t_y = abs(dot(vec3(0,1,0), normal));
    FragColor = cliff_albedo + ground_albedo*t_y;


    float contour = 1.0 - step(0.01, fract(v2f.height));
    // FragColor += vec3(contour);

    FragColor = mix(FragColor, u_color_tint.rgb, u_color_tint.a);

    bvec3 na = isnan(FragColor);
    if (na.x || na.y || na.z) {
        FragColor = vec3(1,0,0);
    }

    bvec3 nf = isinf(FragColor);
    if (nf.x || nf.y || nf.z) {
        FragColor = vec3(0,1,0);
    }
}
#endif