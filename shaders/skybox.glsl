
IO FragData {
    vec3 pos;
} v2f;

#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "../grax/shaders/camera.glsl"

layout (location = 0) in vec3 a_Pos;

void main() {
    v2f.pos = a_Pos;
    // gl_Position = camera.projection * camera.view * vec4(a_Pos, 0);

    vec4 clip_pos = camera.projection * mat4(mat3(camera.view)) * vec4(a_Pos, 1);
    gl_Position = clip_pos.xyww;
}

#endif




#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

out vec4 FragColor;

void main() {
    vec3 sky_dir = normalize(v2f.pos);
    FragColor = vec4(abs(sky_dir), 1.0);
}

#endif