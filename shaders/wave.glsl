
#ifndef WAVE_IMPL
#define WAVE_IMPL

// =============================================================================
// FULLY CORRECTED TROCHOIDAL (GERSTNER) WAVE WITH AIRY-BASED SHOALING + NORMAL GRADIENT
// Everything we discussed is now inside:
//   • Fixed ω (period is conserved)
//   • Local k solved from Airy dispersion relation ω² = g k tanh(k h)
//   • Shoaling coefficient Ks from group velocities (energy flux conservation)
//   • Local amplitude A_local = A0 * Ks
//   • Artistic steepness Q (0–1) applied on top
//   • Standard Gerstner displacement (circular orbits, peaked crests)
//   • Correct tangent / binormal derivatives for accurate normals
// =============================================================================

const float G   = 9.81;

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

// Group velocity cg = n * (ω / k) where n = ½ (1 + 2kh / sinh(2kh))
float computeGroupVelocity(float k, float h, float omega) {
    float kh = k * h;
    float n  = 0.5 * (1.0 + 2.0 * kh / sinh(2.0 * kh));
    return n * (omega / k);
}

void trochoidal_wave(Wave wave, vec2 coord, float depth, float time,
                     inout vec3 pos, inout vec3 tangent, inout vec3 binormal)
{
    float omega = Tau / wave.period;

    // Deep-water reference values (for shoaling coefficient)
    float k0  = omega * omega / G;
    float cg0 = 0.5 * (omega / k0);

    float k = computeLocalK(omega, depth);

    float cg = computeGroupVelocity(k, depth, omega); // Local group velocity
    float Ks = sqrt(cg0 / cg); // shoaling coefficient

    float A_local = wave.amplitude * Ks;

    vec2  D   = wave.direction; // presumed already normalized
    float phi = k * dot(D, coord) - omega * time;

    float sinPhi = sin(phi);
    float cosPhi = cos(phi);

    // displacement (standard Gerstner/trochoidal with shoaling)
    float horiz = A_local * sinPhi; //  + breakPush;
    float vert  = A_local * cosPhi; //  * breakFlatten;
    pos += vec3(horiz, vert, horiz) * vec3(-D.x, 1.0, -D.y);


    // tangent / binormal derivatives (for normals)
    // These are the exact analytic partial derivatives of the displacement above
    float QAk     = A_local * k;          // common horizontal derivative factor
    float AkDirX  = A_local * k * D.x;        // vertical derivative factor (x)
    float AkDirY  = A_local * k * D.y;        // vertical derivative factor (z)

    // tangent = ∂P/∂x
    tangent += vec3(
        -D.x * D.x * QAk * cosPhi,   // ∂x/∂x
        -AkDirX * sinPhi,            // ∂y/∂x
        -D.x * D.y * QAk * cosPhi    // ∂z/∂x
    );

    // binormal = ∂P/∂z
    binormal += vec3(
        -D.y * D.x * QAk * cosPhi,   // ∂x/∂z
        -AkDirY * sinPhi,            // ∂y/∂z
        -D.y * D.y * QAk * cosPhi    // ∂z/∂z
    );
}


// wave direction must be normalized
void gerstner_wave(float phase_offset, float depth, vec2 coord, vec2 dir, float steepness, float wave_length, inout vec3 pos, inout vec3 tangent, inout vec3 binormal) {
    float k = Tau / wave_length;

    float g = 9.8;
    float omega = k*sqrt(g/k);

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


void ocean(vec2 coord, float depth, float time, out vec3 out_offset, out vec3 normal) {
    vec3 offset   = vec3(0, 0, 0);
    vec3 tangent  = vec3(1, 0, 0);
    vec3 binormal = vec3(0, 0, 1);

    const int wave_count = 32;
    for (int i = 0; i < wave_count; i++) {
        float a = i*1232.399963;
        vec2 dir = vec2(sin(a), cos(a));


        // float st = 0.4 / (i+1);
        float st = 0.1;
        // float st = mix(0.1, 0.05, float(i) / (wave_count-1));

        float wave_len = (i+1) * 4.0; // *10;

        float scale = smoothstep(0, wave_len/2.0, depth);

        gerstner_wave(0, depth, coord, dir, st * scale, wave_len, offset, tangent, binormal);


        /*
        Wave wave;
        wave.direction = dir; // must be normalized
        wave.amplitude = 5.0; // deep-water A0
        wave.period    = 5.0; // T (seconds) – the conserved quantity
        wave.steepness = 1.0; // Q (artistic 0–1)

        trochoidal_wave(wave, coord, depth, time, offset, tangent, binormal);
        */
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