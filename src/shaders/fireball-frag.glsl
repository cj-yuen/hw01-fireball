#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.

uniform float u_Time;
uniform float u_Strength;
uniform int u_Octaves;
uniform float u_Alpha;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

in float fs_Height;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

// Simple noise
float simpleNoise(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898,78.233, 45.164))) * 43758.5453);
}

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * simpleNoise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// Fire gradient: 0 = yellow core, 1 = red outer
vec3 fireGradient(float t) {
    vec3 yellow = vec3(1.0, 0.95, 0.0);
    vec3 orange = vec3(1.0, 0.55, 0.0);
    vec3 red    = vec3(0.8, 0.05, 0.0);

    if (t < 0.5) {
        float u = smoothstep(0.0, 0.5, t);
        return mix(yellow, orange, u);
    } else {
        float u = smoothstep(0.5, 1.0, t);
        return mix(orange, red, u);
    }
}

void main() {
    // Calculate the diffuse term
    float diffuseTerm = dot(normalize(fs_Nor.xyz), normalize(fs_LightVec.xyz));
    float ambientTerm = 0.4;
    diffuseTerm = diffuseTerm * 0.6 + 0.4;
    float lightIntensity = max(diffuseTerm, 0.0) + ambientTerm;

    // Normalize displacement height [0,1]
    float h = clamp(fs_Height * 0.5 + 0.5, 0.0, 1.0);

    // Fire color gradient
    vec3 fireColor = fireGradient(h);

    // Tint
    fireColor *= mix(vec3(1.0), fs_Col.rgb * u_Color.rgb, .2);

    // Flickering over time
    float flicker = fbm(fs_Pos.xyz * 0.05);
    flicker = 0.8 + 0.4 * flicker;

    // Radial distance for glow/fade
    float radialDistance = length(fs_Pos.xyz);
    float dist = clamp(radialDistance * 0.2, 0.0, 1.0);
    float glow = exp(-6.0 * dist) * flicker;

    // Alpha
    float alpha = u_Alpha;
    alpha *= (1.0 - dist);
    alpha *= mix(0.8, 1.2, flicker);
    alpha = clamp(alpha, 0.0, 1.0);

    vec3 finalColor = fireColor * lightIntensity * (1.0 + glow);
    out_Col = vec4(finalColor, alpha);
}
