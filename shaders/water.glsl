
IO FragData {
    vec3 normal;
    vec2 uv;
} v2f;

#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "../grax/shaders/camera.glsl"

layout (location = 0) in vec3 a_Pos;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec2 a_Uv;

layout (std140) uniform Instances {
    mat4 transform[16];
} instances;

void main() {
    mat4 model = instances.transform[gl_InstanceID];
    v2f.normal = (model * vec4(a_Normal, 0.0)).xyz;
    v2f.uv = a_Uv;
    gl_Position = camera.projection * camera.view * model * vec4(a_Pos, 1.0);
}

#endif


#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

uniform sampler2D tex;

out vec4 FragColor;

void main() {
    FragColor = texture(tex, v2f.uv);
    // FragColor = vec4(0.1, 0.2, 0.6, 1);
    // FragColor = vec4(v2f.uv, 0.0, 1.0);
}
#endif