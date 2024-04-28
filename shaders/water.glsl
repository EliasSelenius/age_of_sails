
#include "../grax/shaders/app.glsl"

#define Pi 3.14159265359
#define Tau (2.0 * Pi)

IO FragData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
} v2f;

#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "../grax/shaders/camera.glsl"


layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;


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
    vec4 wpos = vec4(a_Pos, 1.0);

    vec3 tangent  = vec3(1, 0, 0);
    vec3 binormal = vec3(0, 0, 1);

    gerstner_wave(wpos.xz, normalize(vec2(1, 1.3)), 0.25, 18, wpos.xyz, tangent, binormal);

    v2f.pos = (camera.view * wpos).xyz;
    v2f.normal = mat3(camera.view) * normalize(cross(binormal, tangent));
    v2f.uv = a_Uv;
    gl_Position = camera.projection * camera.view * wpos;
}

#endif


#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


layout (binding = 0) uniform sampler2D g_buffer_pos;
layout (binding = 1) uniform sampler2D water_tex;

out vec4 FragColor;

// how deep into water can you see before it gets completely opaque
uniform float visibility_distance = 5.0;

void main() {
    vec3 water_color = vec3(0.2, 0.5, 0.8);

    vec2 screen_uv = gl_FragCoord.xy / ViewportSize;

    float geom_depth = length(texture(g_buffer_pos, screen_uv).xyz);
    if (geom_depth < 0.001) geom_depth = 9999.0; // TODO: we might be able to remove this if statement when we implement skybox
    float depth = geom_depth - length(v2f.pos);

    float alpha = clamp(depth / visibility_distance, 0, 1);

    vec3 color = texture(water_tex, v2f.uv).rgb * water_color;
    color += vec3(step(alpha, 0.01));
    alpha += step(alpha, 0.01);

    FragColor = vec4(color, alpha);
    // FragColor = vec4(lerp_percent, lerp_percent, lerp_percent, 1.0);
    // FragColor = vec4(geom_depth, geom_depth, geom_depth, 1.0);
}
#endif