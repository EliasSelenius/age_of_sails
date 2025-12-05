
layout (local_size_x = 1, local_size_y = 1) in;

uniform image2D u_image;

void main() {
    ivec2 inv_coord = ivec2(gl_GlobalInvocationID.xy);

    vec4 pixel = imageLoad(u_image, inv_coord);
    imageStore(u_image, inv_coord, vec4(0.0));
}
