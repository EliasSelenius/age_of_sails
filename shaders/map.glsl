

#include "../grax/shaders/common.glsl"
#include "../grax/shaders/app.glsl"
#include "shaders/ground.glsl"

uniform mat3 camera_matrix = mat3(1.0);
uniform float u_contour_width = 0.85;
uniform vec4  u_contour_color = vec4(0.0, 0.0, 0.0, 0.2);

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
in FragData_Block frag_input;
out vec4 FragColor;

void main() {

    vec2 coord = frag_input.coord;
    vec4 ter = terrain_noise(coord);
    float height = ter.w;
    vec3 normal = ter.xyz;

    // float light = mix(0.5, 1.0, dot(normal, vec3(0, 0, 1)));
    float light = dot(normal, vec3(0, 1, 0));

    vec3 color_shallow = vec3(0.1, 0.4, 0.7);
    vec3 color_water   = vec3(0, 0, 1);
    vec3 color_land    = vec3(0, 1, 0);

    vec3 color = color_land;
    if (height < 0) {
        color = mix(color_water, color_shallow, exp(height / 100));
    }

    color *= light;

    float zoom = camera_matrix[0][0];
    float e = u_contour_width;
    float t = abs(fract(height) - 0.5)*2.0;
    float contour = smoothstep(e, 1.0, t);// * clamp(30.0 / zoom, 0, 1);

    vec3 contour_color = mix(color, u_contour_color.rgb, u_contour_color.a);

    FragColor = vec4(mix(color, contour_color, contour), 1.0);
}
#endif