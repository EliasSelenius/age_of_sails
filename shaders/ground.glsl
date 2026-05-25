
vec4 get_terrain(sampler2D height_map, vec2 uv) {

    /*
        p3
    p4  p1  p2
        p5
    */

    ivec2 res = textureSize(height_map, 0);
    ivec2 coord = ivec2(uv * (res - ivec2(1)));

    float h1 = texelFetch(height_map, coord, 0).x;
    float h2 = texelFetch(height_map, coord + ivec2(1, 0), 0).x;
    float h3 = texelFetch(height_map, coord + ivec2(0, 1), 0).x;
    float h4 = texelFetch(height_map, coord + ivec2(-1, 0), 0).x;
    float h5 = texelFetch(height_map, coord + ivec2(0, -1), 0).x;

    vec3 p1 = vec3(0,  h1,  0);
    vec3 p2 = vec3(1,  h2,  0);
    vec3 p3 = vec3(0,  h3,  1);
    vec3 p4 = vec3(-1, h4,  0);
    vec3 p5 = vec3(0,  h5, -1);

    vec3 normal = normalize(cross(p3 - p1, p2 - p1) +
                            cross(p4 - p1, p3 - p1) +
                            cross(p5 - p1, p4 - p1) +
                            cross(p2 - p1, p5 - p1));

    return vec4(normal, h1);
}

vec4 noise_test(vec2 coord) {
    float largest_f = 1300.0;
    float largest_a = 350.0;

    float smalest_f = 5;
    float smalest_a = 1;

    float h = 0;
    vec2 grad = vec2(0.0);
    for (int i = 0; i < 8; i++) {
        float d = 1.0 / pow(2, i);
        // float f = largest_f * d;
        // float a = largest_a * d;

        float f = mix(smalest_f, largest_f, d);
        float a = mix(smalest_a, largest_a, d);

        vec3 n = noised2(coord / f);
        h += a*n.z;
        grad += (a/f)*n.xy;
    }

    vec3 norm = normalize(vec3(-grad.x, 1, -grad.y));
    return vec4(norm, h);
}