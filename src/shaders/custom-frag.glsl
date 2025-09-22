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

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

// Simple hash-based 3D noise
float simpleNoise(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898,78.233, 45.164))) * 43758.5453);
}

// fBm noise
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 0.01;
    for (int i = 0; i < 5; ++i) {
        value += amplitude * simpleNoise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void main() {
    // Calculate the diffuse term 
    float diffuseTerm = dot(normalize(fs_Nor.xyz), normalize(fs_LightVec.xyz));
    float ambientTerm = 0.25;
    float lightIntensity = max(diffuseTerm, 0.0) + ambientTerm;

    // FBM noise
    float n = fbm(fs_Pos.xyz * 0.00003 + vec3(u_Time * 0.00003, u_Time * 0.00001, u_Time * 0.00002));
    n = clamp(n, 0.0, 1.0);

    // Color palette blending
    vec3 colorA = vec3(1.0, 0.8, 0.2); // yellow
    vec3 colorB = vec3(0.2, 0.4, 1.0); // blue
    vec3 colorC = vec3(0.8, 0.2, 0.6); // magenta
    vec3 colorD = u_Color.rgb;          // user color

    // Blend between 4 colors based on noise
    vec3 noisyColor = mix(colorA, colorB, smoothstep(0.0, 0.33, n));
    noisyColor = mix(noisyColor, colorC, smoothstep(0.33, 0.66, n));
    noisyColor = mix(noisyColor, colorD, smoothstep(0.66, 1.0, n));

    out_Col = vec4(noisyColor * lightIntensity, u_Color.a);
}
