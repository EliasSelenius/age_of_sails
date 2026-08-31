
#ifndef WAVE_IMPL
#define WAVE_IMPL

const float G = 9.81;

struct Wave {
    vec2  direction;   // must be normalized
    float amplitude;   // deep-water A0
    float period;      // T (seconds) – the conserved quantity
    float steepness;   // Q (artistic 0–1)
};

// Newton-Raphson solve for local wave number k (5 iterations = plenty accurate)
float computeLocalK(float omega, float h) {
    if (h < 0.01) return omega * omega / G; // shallow fallback

    float k = omega * omega / G; // deep-water guess
    for (int i = 0; i < 5; ++i) {
        float kh      = k * h;
        float tanh_kh = tanh(kh);
        float f       = G * k * tanh_kh - omega * omega;
        float df      = G * (tanh_kh + kh * (1.0 - tanh_kh * tanh_kh)); // derivative
        k -= f / df;
        if (k < 0.0) k = 0.0;
    }

    return max(k, 0.0001);
}

float coth(float x) {
    float e = exp(2.0*x);
    return (e+1)/(e-1);
}

// float wavenumber_guo_approximation(float omega, float h) {
//     float mu0 = omega*omega*h/G;
//     float alpha = sqrt(mu0);
//     float pcp = pow(coth(pow(alpha, 3.0/2.0)), 2.0/3.0);
//     float k = omega * omega * pcp / G;
//     return k;
// }

float wavenumber_guo_approximation(float omega, float h) {
    float mu0 = omega*omega*h/G;
    float pcp = pow(coth(pow(mu0, 3.0/4.0)), 2.0/3.0);
    float k = omega * omega * pcp / G;
    return k;
    // return max(k, 0.0001);
}


// Group velocity cg = n * (ω / k) where n = ½ (1 + 2kh / sinh(2kh))
float compute_group_velocity(float k, float h, float omega) {
    float kh = k * h;
    float n  = 0.5 * (1.0 + 2.0 * kh / sinh(2.0 * kh));
    return n * (omega / k);
}

void trochoidal_wave(Wave wave, vec2 coord, float depth, float time,
                     inout vec3 pos, inout vec3 tangent, inout vec3 binormal)
{
    float omega = Tau / wave.period; // omega, angular frequency, a conserved quantity

    // Deep-water reference values (for shoaling coefficient)
    float k0  = omega * omega / G;
    float cg0 = 0.5 * (omega / k0);

    // float k = computeLocalK(omega, depth);
    float k = wavenumber_guo_approximation(omega, depth);

    float cg = compute_group_velocity(k, depth, omega); // Local group velocity
    float Ks = sqrt(cg0 / cg); // shoaling coefficient

    if (isnan(Ks)) { // at large depths wavenumber_guo_approximation or compute_group_velocity may return NaN
        k = k0;
        Ks = 1.0;
    }

    float A_local = wave.amplitude * Ks;

    vec2  D   = wave.direction; // presumed already normalized
    float phi = k * dot(D, coord) - omega * time;

    float s = sin(phi);
    float c = cos(phi);

    pos      +=  vec3(-D.x, 1.0, -D.y)       * vec3(s, c, s) * A_local;
    tangent  += -vec3(D.x*D.x, D.x, D.x*D.y) * vec3(c, s, c) * A_local * k;
    binormal += -vec3(D.y*D.x, D.y, D.y*D.y) * vec3(c, s, c) * A_local * k;
}


// wave direction must be normalized
void gerstner_wave(float phase_offset, float depth, vec2 coord, vec2 dir, float steepness, float wave_length, inout vec3 pos, inout vec3 tangent, inout vec3 binormal) {
    float k = Tau / wave_length;

    float g = 9.8;
    float omega = k*sqrt(g/k);
    // float omega = sqrt(g*k);

    /*
        shoaling:
        wave velocity decreases
        corresponding decrese in wave length
        for conservation of energy there is an increase in amplitude

        amplitude = steepness * wave_length / Tau
        wave_height = 2 * amplitude

        if amplitude < wave_length / Tau
        then the wave breaks (I think?)
    */



    float f = k*phase_offset + k*dot(dir, coord) - omega * Time;

    float s = sin(f);
    float c = cos(f);


    pos      += vec3( c, s,  c) * vec3(dir.x, 1.0, dir.y)                   * steepness / k;
    tangent  += vec3(-s, c, -s) * vec3(dir.x * dir.x, dir.x, dir.x * dir.y) * steepness;
    binormal += vec3(-s, c, -s) * vec3(dir.x * dir.y, dir.y, dir.y * dir.y) * steepness;
}

uniform float u_amplitude_factor = 0.2;
void ocean(vec2 coord, float depth, float time, out vec3 out_offset, out vec3 normal) {
    vec3 offset   = vec3(0, 0, 0);
    vec3 tangent  = vec3(1, 0, 0);
    vec3 binormal = vec3(0, 0, 1);

    const int wave_count = 32;
    for (int i = 0; i < wave_count; i++) {
        float a = i*1232.399963;
        vec2 dir = vec2(sin(a), cos(a));


        // // float st = 0.4 / (i+1);
        // float st = 0.1;
        // // float st = mix(0.1, 0.05, float(i) / (wave_count-1));

        // float wave_len = (i+1) * 4.0; // *10;

        // float scale = smoothstep(0, wave_len/2.0, depth);

        // gerstner_wave(0, depth, coord, dir, st * scale, wave_len, offset, tangent, binormal);




        float T  = mix(1.5, 20.0, float(i) / (wave_count-1));
        float L0 = G/Tau * T*T;
        float scale = smoothstep(0, L0/2.0, depth);
        float A0 = 1.0/14.0 * L0 * u_amplitude_factor * scale;

        Wave wave;
        wave.direction = dir; // must be normalized
        wave.amplitude = A0; // 5.0; // deep-water A0
        wave.period    = T; // 5.0; // T (seconds) – the conserved quantity
        wave.steepness = 1.0; // Q (artistic 0–1)

        trochoidal_wave(wave, coord, depth, time, offset, tangent, binormal);
    }


    // vec2 wave_pos = vec2(40, 100);
    // vec2 dir = wave_pos - coord;
    // float phase = length(dir);
    // dir = phase == 0 ? vec2(0) : normalize(dir);
    // gerstner_wave(phase, depth, vec2(0), dir, 0.6*exp(-phase*0.01), 18, offset, tangent, binormal);

    out_offset = offset;
    normal = normalize(cross(tangent, binormal));
}

#endif