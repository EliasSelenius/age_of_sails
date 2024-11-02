
#include "../grax/shaders/camera.glsl"


IO FragData {
    vec3 pos;
} v2f;



#ifdef VertexShader /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

layout (location = 0) in vec3 a_Pos;

void main() {
    v2f.pos = a_Pos;

    vec4 clip_pos = camera.projection * mat4(mat3(camera.view)) * vec4(a_Pos, 1);
    gl_Position = clip_pos.xyww;
}

#endif




#ifdef FragmentShader ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "../grax/shaders/app.glsl"

out vec4 FragColor;


void main() {

    vec3 sun_dir      = camera.sun_dir.xyz;
    vec3 sun_radiance = camera.sun_radiance.xyz;

    vec3 sky_dir = normalize(v2f.pos);

    float fCos = dot(sun_dir, -sky_dir);

    float g = -0.95;
    float g2 = g*g;
    float MiePhase = 1.5 * ((1.0 - g2) / (2.0 + g2)) * (1.0 + fCos*fCos) / pow(1.0 + g2 - 2.0*g*fCos, 1.5);

    vec3 sky_color = vec3(0.1, 0.1, 1);

    FragColor = vec4(sky_color + vec3(MiePhase), 1.0);

    // FragColor = vec4(abs(sky_dir), 1.0);
}

#endif



// FragColor.rgb = acc_color * (v3InvWavelength * fKrESun + vec3(fMiePhase * fKmESun));