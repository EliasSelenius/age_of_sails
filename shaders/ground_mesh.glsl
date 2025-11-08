
#extension GL_ARB_bindless_texture : require

#include "../grax/shaders/noise.glsl"
#include "../grax/shaders/camera.glsl"
#include "shaders/ground.glsl"

IO FragData {
    vec3 pos;
    vec3 normal;
    vec3 view_pos;
    vec3 view_normal;
    vec2 uv;
} v2f;

uniform vec2 u_chunk_pos;
uniform vec4 u_color_tint = vec4(0.0);
uniform int u_chunk_size;

layout (binding = 0) uniform sampler2D height_map;
layout (binding = 1) uniform sampler2D texture_albedo_sand;
layout (binding = 2) uniform sampler2D texture_albedo_grass;
layout (binding = 3) uniform sampler2D texture_albedo_cliff;

// layout(std430) readonly buffer PerInstanceData {
//     vec2 chunk_pos[];
// };


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
}


#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

void main() {
    // vec2 chunk_pos = chunk_pos[gl_InstanceID];
    vec2 chunk_pos = u_chunk_pos;


    vec3 vertex_pos = a_Pos;

    // int region_size = 128;
    // int id = gl_VertexID;
    // int s = u_chunk_size + 1;
    // vec3 vertex_pos = (vec3(id / s, 0, id % s) - vec2((s-1)/2.0, 0).xyx) / float(s-1) * region_size;

    vec4 pos = vec4(vertex_pos, 1.0) + vec4(chunk_pos.x, 0, chunk_pos.y, 0);
    vec4 n = noise_test(pos.xz);
    pos.y = n.w;

    vec4 view_pos = camera.view * pos;

    vec3 normal = n.xyz;
    vec3 view_normal = mat3(camera.view) * normal;

    v2f.pos = pos.xyz;
    v2f.normal = normal;
    v2f.view_pos = view_pos.xyz;
    v2f.view_normal = view_normal;
    v2f.uv = a_Uv;

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
    vec4 p0 = gl_in[0].gl_Position;
    vec4 p1 = gl_in[1].gl_Position;
    vec4 p2 = gl_in[2].gl_Position;
    vec4 p3 = gl_in[3].gl_Position;

    // vec2 uv = gl_TessCoord.xy;
    vec4 vert_pos = mix(mix(p0, p1, gl_TessCoord.x),
                        mix(p2, p3, gl_TessCoord.x),
                        gl_TessCoord.y);


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


    vec3 albedo_sand = texture(texture_albedo_sand, v2f.uv).rgb;
    vec3 albedo_grass = texture(texture_albedo_grass, v2f.uv).rgb;
    vec3 ground_albedo = mix(albedo_sand, albedo_grass, smoothstep(10, 15, v2f.pos.y));

    vec2 cliff_uv_x = vec2(v2f.pos.x, v2f.pos.y) / 100.0;
    vec2 cliff_uv_z = vec2(v2f.pos.z, v2f.pos.y) / 100.0;
    vec3 cliff_albedo_x = texture(texture_albedo_cliff, cliff_uv_x).rgb;
    vec3 cliff_albedo_z = texture(texture_albedo_cliff, cliff_uv_z).rgb;
    float t_x = abs(dot(vec3(1,0,0), normal));
    float t_z = abs(dot(vec3(0,0,1), normal));
    vec3 cliff_albedo = cliff_albedo_x*t_x + cliff_albedo_z*t_z;

    float e = 0.01;
    float s = 1.0 / sqrt(2);
    FragColor = mix(cliff_albedo, ground_albedo, smoothstep(s-e, s+e, dot(vec3(0,1,0), normal)));


    float contour = 1.0 - step(0.01, fract(v2f.pos.y));
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