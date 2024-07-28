

vec3 hash(vec3 p) {
	p = vec3(dot(p,vec3(127.1,311.7, 74.7)),
			 dot(p,vec3(269.5,183.3,246.1)),
			 dot(p,vec3(113.5,271.9,124.6)));

	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
	vec3 u = f*f*(3.0-2.0*f);

    vec3 p000 = vec3(0.0, 0.0, 0.0);
    vec3 p100 = vec3(1.0, 0.0, 0.0);
    vec3 p010 = vec3(0.0, 1.0, 0.0);
    vec3 p110 = vec3(1.0, 1.0, 0.0);
    vec3 p001 = vec3(0.0, 0.0, 1.0);
    vec3 p101 = vec3(1.0, 0.0, 1.0);
    vec3 p011 = vec3(0.0, 1.0, 1.0);
    vec3 p111 = vec3(1.0, 1.0, 1.0);

    return mix(mix(mix(dot(hash(i + p000), f - p000),
                       dot(hash(i + p100), f - p100), u.x),
                   mix(dot(hash(i + p010), f - p010),
                       dot(hash(i + p110), f - p110), u.x), u.y),
               mix(mix(dot(hash(i + p001), f - p001),
                       dot(hash(i + p101), f - p101), u.x),
                   mix(dot(hash(i + p011), f - p011),
                       dot(hash(i + p111), f - p111), u.x), u.y), u.z);
}

float ground_height(vec3 coord) {
    float h = -40.0;
    // for (int i = 1; i <= 5; i++) {
    //     float scale = i*20;
    //     h += noise((coord+vec3(i*1000)) / (scale*5)) * scale;
    // }
    return h;
}

float ground(vec2 coord, out vec3 normal) {
    vec3 p1 = vec3(coord.x, 0, coord.y);
    vec3 p2 = p1 + vec3(1, 0, 0);
    vec3 p3 = p1 + vec3(0, 0, 1);

    p1.y = ground_height(p1);
    p2.y = ground_height(p2);
    p3.y = ground_height(p3);

    vec3 tangent = p2 - p1;
    vec3 binormal = p3 - p1;

    normal = normalize(cross(binormal, tangent));
    return p1.y;
}
