
#include "../grax/shaders/app.glsl"
#include "../grax/shaders/camera.glsl"
#include "../grax/shaders/lights.glsl"
#include "shaders/ground.glsl"


#define Pi 3.14159265359
#define Tau (2.0 * Pi)

layout (binding = 0) uniform sampler2D g_buffer_pos;
layout (binding = 1) uniform sampler2D water_tex;
layout (binding = 2) uniform sampler2D height_map;

uniform vec2 water_pos;
uniform float depth_factor = 0.13;


#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

void main() {
    gl_Position = vec4(a_Pos, 1.0);
}
#endif


#ifdef TessControl //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (vertices = 4) out;

float get_tess_level(vec2 coord) {

    vec4 pos = vec4(coord.x, 0.0, coord.y, 1.0);
    float dist = length((camera.view * pos).xyz);


    float min_dist = 0; //  128;
    float max_dist = 128*30;

    float min_tess = 1;
    float max_tess = 128;

    return mix(min_tess, max_tess, clamp(pow((max_dist - dist) / (max_dist - min_dist), 16), 0.0, 1.0));
}

void main() {
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;


    float d = 128.0 / 2.0;
    gl_TessLevelOuter[0] = get_tess_level(water_pos + vec2( 0, -d)); // -z
    gl_TessLevelOuter[1] = get_tess_level(water_pos + vec2(-d,  0)); // -x
    gl_TessLevelOuter[2] = get_tess_level(water_pos + vec2( 0,  d)); // +z
    gl_TessLevelOuter[3] = get_tess_level(water_pos + vec2( d,  0)); // +x

    float level = get_tess_level(water_pos);
    gl_TessLevelInner[0] = level;
    gl_TessLevelInner[1] = level;
}
#endif


#ifdef TessEval /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (quads, equal_spacing, ccw) in;

out FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
} v2f;

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

void main() {
    vec2 uv = gl_TessCoord.xy;

    vec4 p0 = gl_in[0].gl_Position;
    vec4 p1 = gl_in[1].gl_Position;
    vec4 p2 = gl_in[2].gl_Position;
    vec4 p3 = gl_in[3].gl_Position;

    vec4 vert_pos = mix(mix(p0, p1, uv.x), mix(p2, p3, uv.x), uv.y);


    vec4 terrain = get_terrain(height_map, uv);
    float depth = -terrain.w;
    vec2 shore_dir = -normalize(terrain.xz);

    float scaling_factor = smoothstep(0.0, 60.0, depth);
    float wave_steepness = scaling_factor;
    float shore_wave_steepness = 1 - wave_steepness;

    // shore_wave_steepness *= step(dot(terrain.xyz, vec3(0, 1, 0)), 0.99);

    vec3 water_offset = vec3(0, 0, 0);
    vec3 tangent  = vec3(1, 0, 0);
    vec3 binormal = vec3(0, 0, 1);

    vec2 coord = water_pos + vert_pos.xz;

    const int iterations = 12;
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

    vec4 wpos = vert_pos;
    wpos.xz += water_pos;
    wpos.xyz += water_offset;

    v2f.pos = (camera.view * wpos).xyz;
    v2f.normal = mat3(camera.view) * normal;
    v2f.uv = uv * 10;
    gl_Position = camera.projection * camera.view * wpos;
}
#endif


#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
in FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
} v2f;

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

    if (!gl_FrontFacing) {
        g.normal = -g.normal;
    }

    vec3 sun_dir      = camera.sun_dir.xyz;
    vec3 sun_radiance = camera.sun_radiance.xyz;
    vec3 light = calc_dir_light(sun_dir, sun_radiance, g);
    float ambient = camera.sun_radiance.w;
    light += sun_radiance * g.albedo * ambient;

    FragColor = vec4(light, color.a);

    // float b = 0.0005;
    // FragColor = mix(FragColor, vec4(0.5, 0.6, 0.7, 1.0), 1 - exp(-length(v2f.pos)*b));

    if (gl_FrontFacing) { // atmosphere
        float sun_amount = maxdot(normalize(v2f.pos), normalize(mat3(camera.view) * camera.sun_dir.xyz));
        vec3 fog_color = mix(vec3(0.5, 0.6, 0.7), // blue
                             vec3(1.0, 0.9, 0.7), // yellow
                             pow(sun_amount, 8.0));

        float b = 0.0005;
        FragColor = mix(FragColor, vec4(fog_color, 1.0), 1 - exp(-length(v2f.pos)*b));


        // float b = 0.0005;
        // FragColor = mix(FragColor, vec4(0.5, 0.6, 0.7, 1.0), 1 - exp(-length(v2f.pos)*b));
    } else { // water
        float b = 0.005;
        FragColor = mix(FragColor, vec4(0.1, 0.4, 0.7, 1.0), 1 - exp(-length(v2f.pos)*b));
    }

}
#endif