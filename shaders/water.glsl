
#include "../grax/shaders/prelude.glsl"
#include "../grax/shaders/app.glsl"
#include "../grax/shaders/camera.glsl"
#include "../grax/shaders/lights.glsl"
#include "../grax/shaders/noise.glsl"
#include "../grax/shaders/common.glsl"
#include "shaders/ground.glsl"
#include "shaders/wave.glsl"


layout (binding = 0) uniform sampler2D g_buffer_pos;
layout (binding = 1) uniform sampler2D water_tex;
layout (binding = 2) uniform sampler2D height_map;

uniform float depth_factor = 0.05;
uniform float u_water_roughness = 0.4;

struct InstanceData {
    mat4 model;
    vec4 uv_offset_scale;
    vec4 albedo_color;
    vec2 metallic_roughness;
    // sampler2D albedo_texture;
    uvec2 albedo_texture;
};

layout (std140) readonly buffer Instances {
    InstanceData instances[];
};


#define VertexOutput VertexOutput_Block {\
    vec2 chunk_coord;\
    flat uint instance_id;\
}\

#define TessControlOutput TessControlOutput_Block {\
    vec2 chunk_coord;\
    flat uint instance_id;\
}\

#define TessEvalOutput TessEvalOutput_Block {\
    vec3 world_pos;\
    vec3 world_normal;\
    vec3 view_pos;\
    vec3 view_normal;\
    vec2 uv;\
    flat uint instance_id;\
}\



float get_tess_level(vec2 coord) {

    vec4 pos = vec4(coord.x, 0.0, coord.y, 1.0);
    float dist = length((camera.view * pos).xyz);


    float min_dist = 0; //  128;
    float max_dist = 128*15;

    float min_tess = 1;
    float max_tess = 128; // TODO: prob max out at 64 or 32

    return mix(min_tess, max_tess, clamp(pow((max_dist - dist) / (max_dist - min_dist), 4), 0.0, 1.0));
}



#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

out VertexOutput vs_output;

void main() {
    uint instance_id = uint(gl_BaseInstanceARB) + uint(gl_InstanceID);
    InstanceData data = instances[instance_id];

    vs_output.instance_id = instance_id;
    vs_output.chunk_coord = data.model[3].xz;

    gl_Position = data.model * vec4(a_Pos, 1.0);
}
#endif


#ifdef TessControl //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (vertices = 4) out;

in  VertexOutput       tcs_input[];
out TessControlOutput  tcs_output[];

void main() {
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;

    vec2 chunk_coord = tcs_input[gl_InvocationID].chunk_coord;
    uint instance_id = tcs_input[gl_InvocationID].instance_id;

    tcs_output[gl_InvocationID].chunk_coord = chunk_coord;
    tcs_output[gl_InvocationID].instance_id = instance_id;

    float d = 128.0 / 2.0;
    gl_TessLevelOuter[0] = get_tess_level(chunk_coord + vec2( 0, -d)); // -z
    gl_TessLevelOuter[1] = get_tess_level(chunk_coord + vec2(-d,  0)); // -x
    gl_TessLevelOuter[2] = get_tess_level(chunk_coord + vec2( 0,  d)); // +z
    gl_TessLevelOuter[3] = get_tess_level(chunk_coord + vec2( d,  0)); // +x

    float level = get_tess_level(chunk_coord);
    gl_TessLevelInner[0] = level;
    gl_TessLevelInner[1] = level;
}
#endif


#ifdef TessEval /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
layout (quads, equal_spacing, ccw) in;

in  TessControlOutput tes_input[];
out TessEvalOutput    tes_output;

void main() {

    vec4 p0 = gl_in[0].gl_Position;
    vec4 p1 = gl_in[1].gl_Position;
    vec4 p2 = gl_in[2].gl_Position;
    vec4 p3 = gl_in[3].gl_Position;

    uint instance_id = tes_input[0].instance_id;
    tes_output.instance_id = instance_id;

    vec4 vert_pos = mix(mix(p0, p1, gl_TessCoord.x), mix(p2, p3, gl_TessCoord.x), gl_TessCoord.y);

    vec2 uv = (vert_pos.xz + vec2(64.0)) / 128.0; // TODO: hardcoded chunk dimensions

    vec2 coord = vert_pos.xz;

    vec4 terrain = terrain_noise(coord);
    // vec4 terrain = get_terrain(height_map, uv);
    float depth = max(-terrain.w, 0.0);
    vec2 shore_dir = -normalize(terrain.xz);

    vec3 water_offset = vec3(0, 0, 0);
    vec3 normal = vec3(0, 1, 0);
    ocean(coord, depth, Time, water_offset, normal);

    vec4 wpos = vert_pos + vec4(water_offset, 0.0);

    tes_output.world_pos = wpos.xyz;
    tes_output.world_normal = normal;
    tes_output.view_pos = (camera.view * wpos).xyz;
    tes_output.view_normal = mat3(camera.view) * normal;
    tes_output.uv = uv;
    gl_Position = camera.projection * camera.view * wpos;
}
#endif


#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

in TessEvalOutput frag_input;
out vec4 FragColor;

void main() {
    vec2 screen_uv = gl_FragCoord.xy / ViewportSize;

    float dist_to_geometry = length(texture(g_buffer_pos, screen_uv).xyz);
    if (dist_to_geometry < 0.001) dist_to_geometry = 9999.0; // TODO: we might be able to remove this if statement if we clear g_buffer_pos with large z values

    float dist_to_water = length(frag_input.view_pos);
    float depth = dist_to_geometry - dist_to_water;

    // vec4 deep_water = vec4(0.023, 0.051, 0.082, 1.0);
    vec4 deep_water = vec4(0.15, 0.4, 1.0, 1.0);
    vec4 shallow_water = vec4(0.2, 0.6, 0.8, 0.3);
    float alpha = clamp(1 - exp(-depth * depth_factor), 0, 1);
    // vec4 water_color = mix(shallow_water, deep_water, alpha); // * texture(water_tex, frag_input.uv);
    vec4 water_color = deep_water;
    water_color.a = 0.3;


    // shore line foam
    vec4 shore_line_color = vec4(step(alpha, 0.01)) * exp(-dist_to_water * 0.005);

    // foam
    // vec2 p = u_water_pos + frag_input.uv*128;
    // float d = voronoi(p*0.2);
    // d = smoothstep(0.5, 2.0, d);
    // vec4 foam_color = vec4(vec3(d), 0.0);


    vec4 color = water_color;// + shore_line_color + foam_color;

    Geometry g;
    g.view_pos = frag_input.view_pos;
    g.view_normal = -normalize(frag_input.view_normal); // TODO: why did normals get inverted here? strange...
    g.albedo = color.rgb;
    g.roughness = u_water_roughness;
    g.metallic  = 0.0;

    Material mat;
    mat.albedo    = vec3(1.0); // color.rgb;
    mat.roughness = g.roughness;
    mat.metallic  = g.metallic;
    // mat.F0        = ;

    vec3 world_normal = normalize(frag_input.world_normal);

    if (!gl_FrontFacing) {
        g.view_normal = -g.view_normal;
        world_normal = -world_normal;
    }


    vec3 sun_dir         = camera.sun_dir.xyz;
    vec3 sun_radiance    = camera.sun_radiance.xyz;
    float ambient_factor = camera.sun_radiance.w;

    vec3 radiance = sun_radiance * max(0.0, dot(sun_dir, vec3(0,1,0)));

    vec3 ambient = radiance * g.albedo * ambient_factor;
    // vec3 light = ambient + calc_dir_light(sun_dir, radiance, g);

    vec3 I = mat3(camera.view) * sun_dir;
    vec3 N = g.view_normal; // world_normal;
    vec3 R = -normalize(input.view_pos);

    Skybox sky = make_skybox(sun_dir);

    vec3 light = vec3(0.0);
    // light += cook_torrance_BRDF(I, N, R, skybox_radiance(sun_dir, sky), mat);
    // light += cook_torrance_BRDF(N, N, R, skybox_radiance(world_normal, sky), mat);

    vec3 r = reflect(-R, N);
    light += cook_torrance_BRDF(r, N, R, skybox_radiance(inverse(mat3(camera.view)) * r, sky), mat);

    light = max(vec3(0.0), light);

    float sss_factor = 1.0 - exp(-max(0.0, frag_input.world_pos.y));
    float upness = dot(world_normal, vec3(0,1,0));
    // light *= mix(1.0, 5.0, 1.0 - upness);


    if (gl_FrontFacing) { // atmosphere

        vec3 cold = vec3(0.5, 0.6, 0.7); // blue
        vec3 warm = vec3(1.0, 0.9, 0.7); // yellow
        // vec3 warm = vec3(1.0, 0.0, 0.0);

        float sun_amount = maxdot(normalize(frag_input.view_pos), normalize(mat3(camera.view) * sun_dir));
        vec3 fog_color = mix(cold, warm, pow(sun_amount, 8.0));

        float b = 0.001;
        float t = 1 - exp(-dist_to_water * b);
        // FragColor = mix(FragColor, vec4(fog_color, 1.0), t);

    } else { // water
        vec4 fog_color = vec4(0.1, 0.4, 0.7, 1.0);
        float max_dist = 100;
        float t = 1 - exp(-dist_to_water / max_dist);
        // FragColor = mix(FragColor, fog_color, t);

        vec3 R = transpose(mat3(camera.view)) * normalize(-frag_input.view_pos);
        vec3 N = world_normal;

        vec3 sky_dir = refract(-R, -N, 1.333);

        Skybox sky = make_skybox(sun_dir);
        vec3 sky_light = skybox_radiance(sky_dir, sky);

        // light += sky_light;
        light += max(vec3(0.0), sky_light);
        color.a = 1.0;
    }

    // FragColor = vec4(light, color.a);
    FragColor = vec4(light, 1.0);
}
#endif