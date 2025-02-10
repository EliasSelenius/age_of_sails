
vec4 get_terrain() {
    float region_size = 400;
    float height_map_res_downscale = 10;

    float height_map_res = region_size / height_map_res_downscale + 2.0;

    float r = 1.0 / height_map_res;
    vec2 uv = r + a_Uv * (height_map_res - 2) / height_map_res;

    float g = 1.0 / (region_size+1);
    float h1 = texture(height_map, uv).x;
    float h2 = texture(height_map, uv + vec2(g, 0)).x;
    float h3 = texture(height_map, uv + vec2(0, g)).x;
    float h4 = texture(height_map, uv + vec2(-g, 0)).x;
    float h5 = texture(height_map, uv + vec2(0, -g)).x;

    float d = (region_size+1) * g;
    vec3 p1 = vec3(0,  h1,  0);
    vec3 p2 = vec3(d,  h2,  0);
    vec3 p3 = vec3(0,  h3,  d);
    vec3 p4 = vec3(-d, h4,  0);
    vec3 p5 = vec3(0,  h5, -d);

    /*
        p3
    p4  p1  p2
        p5
    */

    vec3 normal = normalize(cross(p3 - p1, p2 - p1) +
                            cross(p4 - p1, p3 - p1) +
                            cross(p5 - p1, p4 - p1) +
                            cross(p2 - p1, p5 - p1));

    return vec4(normal, h1);
}

