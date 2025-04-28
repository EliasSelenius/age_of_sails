
#include "../grax/shaders/app.glsl"
#include "../grax/shaders/camera.glsl"
#include "../grax/shaders/lights.glsl"


#define Pi 3.14159265359
#define Tau (2.0 * Pi)

IO FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
} v2f;

layout (binding = 0) uniform sampler2D g_buffer_pos;
layout (binding = 1) uniform sampler2D water_tex;
layout (binding = 2) uniform sampler2D height_map;

uniform vec2 water_pos;
uniform float depth_factor = 0.13;


#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;


#include "shaders/ground.glsl"


// wave direction must be normalized
void gerstner_wave(float phase_offset, vec2 coord, vec2 dir, float steepness, float wave_length, inout vec3 pos, inout vec3 tangent, inout vec3 binormal) {
    float k = Tau / wave_length;
    float f = k * (phase_offset + dot(dir, coord) - sqrt(9.8 / k) * Time);

    float s = sin(f);
    float c = cos(f);

    pos      += vec3( c, s,  c) * vec3(dir.x, 1.0, dir.y)                   * steepness / k;
    tangent  += vec3(-s, c, -s) * vec3(dir.x * dir.x, dir.x, dir.x * dir.y) * steepness;
    binormal += vec3(-s, c, -s) * vec3(dir.x * dir.y, dir.y, dir.y * dir.y) * steepness;
}

uniform int iterations = 12;

void main() {
    vec4 terrain = get_terrain();
    float depth = -terrain.w;
    vec2 shore_dir = -normalize(terrain.xz);

    float scaling_factor = smoothstep(0, 1, depth / 20.0);
    float wave_steepness = scaling_factor;
    float shore_wave_steepness = 1 - wave_steepness;

    // shore_wave_steepness *= step(dot(terrain.xyz, vec3(0, 1, 0)), 0.99);

    vec3 water_offset = vec3(0, 0, 0);
    vec3 tangent  = vec3(1, 0, 0);
    vec3 binormal = vec3(0, 0, 1);

    vec2 coord = water_pos + a_Pos.xz;

    // const int iterations = 32;
    for (int i = 0; i < iterations; i++) {
        float a = i*1232.399963;
        vec2 dir = vec2(sin(a), cos(a));

        // float st = 0.4 / (i+1);
        float st = 0.1;
        // float st = mix(0.1, 0.05, float(i) / (iterations-1));

        float wave_len = (i+1)*10;

        gerstner_wave(0, coord, dir, st * wave_steepness, wave_len, water_offset, tangent, binormal);
    }

    // gerstner_wave(0, coord, normalize(vec2(1, 1.3)), 0.25 * wave_steepness, 18, water_offset, tangent, binormal);
    // gerstner_wave(0, coord, normalize(vec2(1, 0.6)), 0.04 * wave_steepness, 31, water_offset, tangent, binormal);
    // gerstner_wave(0, coord, normalize(vec2(0.5, 1)), 0.10 * wave_steepness, 7,  water_offset, tangent, binormal);
    // gerstner_wave(-depth, vec2(0), shore_dir,        0.25 * shore_wave_steepness, 10, water_offset, tangent, binormal);


    vec3 normal = normalize(cross(binormal, tangent));

    vec4 wpos = vec4(a_Pos, 1.0);
    wpos.xz += water_pos;
    wpos.xyz += water_offset;

    v2f.pos = (camera.view * wpos).xyz;
    v2f.normal = mat3(camera.view) * normal;
    v2f.uv = a_Uv * 10;
    gl_Position = camera.projection * camera.view * wpos;
}

#endif


#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

out vec4 FragColor;

void main() {
    vec2 screen_uv = gl_FragCoord.xy / ViewportSize;

    float geom_depth = length(texture(g_buffer_pos, screen_uv).xyz);
    if (geom_depth < 0.001) geom_depth = 9999.0; // TODO: we might be able to remove this if statement if we clear g_buffer_pos with large z values
    float depth = geom_depth - length(v2f.pos);

    // vec4 deep_water = vec4(0.023, 0.051, 0.082, 1.0);
    vec4 deep_water = vec4(0.15, 0.4, 1.0, 1.0);
    vec4 shallow_water = vec4(0.2, 0.6, 0.8, 0.1);
    float alpha = clamp(1 - exp(-depth * depth_factor), 0, 1);
    vec4 color = mix(shallow_water, deep_water, alpha) * texture(water_tex, v2f.uv);

    // shore line foam
    color += vec4(step(alpha, 0.01)) * exp(-length(v2f.pos) * 0.005);


    Geometry g;
    g.pos = v2f.pos;
    g.normal = v2f.normal;
    g.albedo = color.rgb;
    g.roughness = 0.4;
    g.metallic = 0.0;

    vec3 sun_dir      = camera.sun_dir.xyz;
    vec3 sun_radiance = camera.sun_radiance.xyz;
    vec3 light = calc_dir_light(sun_dir, sun_radiance, g);
    float ambient = camera.sun_radiance.w;
    light += sun_radiance * g.albedo * ambient;

    FragColor = vec4(light, color.a);

    float b = 0.0005;
    FragColor = mix(FragColor, vec4(0.5, 0.6, 0.7, 1.0), 1 - exp(-length(v2f.pos)*b));
}
#endif