
vec4 get_terrain(sampler2D height_map, vec2 a_Uv) {
    // float region_size = 128;
    // float height_map_res_downscale = 4;

    // float height_map_res = region_size / height_map_res_downscale + 2.0;

    // float r = 1.0 / height_map_res;
    // vec2 uv = r + a_Uv * (height_map_res - 2) / height_map_res;

    // float g = 1.0 / (region_size+1);
    // float h1 = texture(height_map, uv).x;
    // float h2 = texture(height_map, uv + vec2(g, 0)).x;
    // float h3 = texture(height_map, uv + vec2(0, g)).x;
    // float h4 = texture(height_map, uv + vec2(-g, 0)).x;
    // float h5 = texture(height_map, uv + vec2(0, -g)).x;

    // float d = (region_size+1) * g;
    // vec3 p1 = vec3(0,  h1,  0);
    // vec3 p2 = vec3(d,  h2,  0);
    // vec3 p3 = vec3(0,  h3,  d);
    // vec3 p4 = vec3(-d, h4,  0);
    // vec3 p5 = vec3(0,  h5, -d);

    /*
        p3
    p4  p1  p2
        p5
    */

    ivec2 res = textureSize(height_map, 0);
    ivec2 uv = ivec2(a_Uv * (res.x - 1));
    float h1 = texelFetch(height_map, uv, 0).x;

    // int pd = uv.x < res.x

    float h2 = texelFetch(height_map, uv + ivec2(1, 0), 0).x;
    float h3 = texelFetch(height_map, uv + ivec2(0, 1), 0).x;
    float h4 = texelFetch(height_map, uv + ivec2(-1, 0), 0).x;
    float h5 = texelFetch(height_map, uv + ivec2(0, -1), 0).x;

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

