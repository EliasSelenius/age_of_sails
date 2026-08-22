

#include "../grax/shaders/common.glsl"
#include "../grax/shaders/app.glsl"
#include "shaders/ground.glsl"

uniform mat3 camera_matrix = mat3(1.0);

#define FragData_Block FragData {\
    vec2 coord;\
}\

#ifdef VertexShader // Per Vertex ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
out FragData_Block out_vertex;

void main() {
    vec4 ndc = screen_covering_quad(gl_VertexID);
    ndc.xy *= 1.0;
    vec2 arcndc = ndc.xy * vec2(Width/Height, 1.0);

    out_vertex.coord = (camera_matrix * vec3(arcndc, 1)).xy;
    out_vertex.coord.x *= -1;

    gl_Position = ndc;
}
#endif



#ifdef FragmentShader // Per Fragment /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
in FragData_Block input;
out vec4 FragColor;

void main() {

    vec2 coord = input.coord;
    vec4 ter = terrain_noise(coord);
    float height = ter.w;
    vec3 normal = ter.xyz;

    float light = dot(normal, vec3(0, 1, 0));

    vec3 color_shallow = vec3(0.1, 0.4, 0.7);
    vec3 color_water   = vec3(0, 0, 1);
    vec3 color_land    = vec3(0, 1, 0);

    vec3 color = color_land;
    if (height < 0) {
        color = mix(color_water, color_shallow, exp(height / 100));
    }

    float contour = smoothstep(0.95, 1.0, fract(height));

    color *= light;

    FragColor = vec4(mix(color, vec3(0), contour), 1.0);
}
#endif