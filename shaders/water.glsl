
#include "../grax/shaders/app.glsl"

#define Pi 3.14159265359
#define Tau (2.0 * Pi)

IO FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
} v2f;

#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "shaders/ground.glsl"
#include "../grax/shaders/camera.glsl"


layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

uniform vec2 water_pos;

// wave direction must be normalized
void gerstner_wave(vec2 coord, vec2 dir, float steepness, float wave_length, inout vec3 pos, inout vec3 tangent, inout vec3 binormal) {
    float k = Tau / wave_length;
    float f = k * (dot(dir, coord) - sqrt(9.8 / k) * Time);

    float s = sin(f);
    float c = cos(f);

    pos      += vec3( c, s,  c) * vec3(dir.x, 1.0, dir.y)                   * steepness / k;
    tangent  += vec3(-s, c, -s) * vec3(dir.x * dir.x, dir.x, dir.x * dir.y) * steepness;
    binormal += vec3(-s, c, -s) * vec3(dir.x * dir.y, dir.y, dir.y * dir.y) * steepness;
}

void main() {
    vec3 water_offset = vec3(0, 0, 0);
    vec3 tangent  = vec3(1, 0, 0);
    vec3 binormal = vec3(0, 0, 1);

    vec2 coord = water_pos + a_Pos.xz;
    gerstner_wave(coord, normalize(vec2(1, 1.3)), 0.25, 18, water_offset, tangent, binormal);
    gerstner_wave(coord, normalize(vec2(1, 0.6)), 0.04, 31, water_offset, tangent, binormal);
    gerstner_wave(coord, normalize(vec2(0.5, 1)), 0.1, 7, water_offset, tangent, binormal);

    // float gr = ground_height(vec3(coord.x, 0, coord.y));
    // float depth = gr <= 0 ? -gr : 0;
    float depth = 100.0;

    // float scaling_factor = clamp(depth / 100.0, 0, 1);
    float scaling_factor = smoothstep(0, 1, depth / 10.0);
    water_offset *= scaling_factor;
    // tangent      *= scaling_factor;
    // binormal     *= scaling_factor;

    vec4 wpos = vec4(a_Pos, 1.0);
    wpos.xz += water_pos;
    wpos.xyz += water_offset;

    v2f.pos = (camera.view * wpos).xyz;
    v2f.normal = mat3(camera.view) * normalize(cross(binormal, tangent));
    v2f.uv = a_Uv + (water_pos * 0.1); // NOTE: the magic number here comes from the uv scaling in the mesh
    gl_Position = camera.projection * camera.view * wpos;
}

#endif


#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "../grax/shaders/camera.glsl"
#include "../grax/shaders/lights.glsl"

layout (binding = 0) uniform sampler2D g_buffer_pos;
layout (binding = 1) uniform sampler2D water_tex;

out vec4 FragColor;

uniform float depth_factor = 0.13;

uniform vec3 sun_dir;
uniform vec3 sun_radiance;


void main() {
    vec2 screen_uv = gl_FragCoord.xy / ViewportSize;

    float geom_depth = length(texture(g_buffer_pos, screen_uv).xyz);
    if (geom_depth < 0.001) geom_depth = 9999.0; // TODO: we might be able to remove this if statement if we clear g_buffer_pos with large z values
    float depth = geom_depth - length(v2f.pos);

    vec4 deep_water = vec4(0.2, 0.4, 0.8, 1.0);
    vec4 shallow_water = vec4(0.2, 0.6, 0.8, 0.1);
    float alpha = 1 - exp(-depth * depth_factor);
    vec4 color = mix(shallow_water, deep_water, alpha) * texture(water_tex, v2f.uv);
    color += vec4(step(depth, 0.1));


    Geometry g;
    g.pos = v2f.pos;
    g.normal = v2f.normal;
    g.albedo = color.rgb;
    g.roughness = 0.5;
    g.metallic = 0.0;
    vec3 light = calc_dir_light(sun_dir, sun_radiance, g);
    FragColor = vec4(light, color.a);
}
#endif