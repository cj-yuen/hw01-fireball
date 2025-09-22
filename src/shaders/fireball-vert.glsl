#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform float u_Time;
uniform float u_Strength;
uniform int u_Octaves;
uniform float u_Alpha;
uniform vec2 u_MousePos;    // Mouse position in normalized coordinates [-1, 1]

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;
out float fs_Height;

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

vec2 random(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(95.2, 125.2)), dot(p, vec2(102.2, 106.3)))) * 5372.3);
}

float worley2D(vec2 pos, float time) {
    // Animate
    vec2 aPos = pos + vec2(0.0, time * 0.2);

    // Swirl motion
    float swirl = time * 0.003;
    aPos += vec2(sin(swirl) * 0.2, cos(swirl) * 0.2);
    
    vec2 uv = aPos;

    vec2 uvInt = floor(uv);
    vec2 uvFract = fract(uv);

    float minDist = 10.0;

    for (int i = -1; i <= 1; ++i) {
        for (int j = -1; j <= 1; ++j) {
            vec2 neighbor = vec2(float(i), float(j));
            vec2 point = random(uvInt + neighbor);
            point = 0.5 + 0.5 * sin(time * 2.0 + 1.623 * point);

            vec2 diff = neighbor + point - uvFract;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }

    return minDist;
}

// Fractal Worley Noise (multi-octave)
float worleyFBM(vec2 pos, float time, int octaves) {
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;

    for (int i = 0; i < octaves; i++) {
        sum += worley2D(pos * freq, time) * amp;
        freq *= 2.0;     // zoom in
        amp *= 0.5;      // reduce contribution
    }
    return sum;
}

vec2 rotate(vec2 pos, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(
        pos.x * c - pos.y * s,
        pos.x * s + pos.y * c
    );
}

void main() {
    fs_Col = vs_Col;
    fs_Pos = vs_Pos;

    float swirlAngle = u_Time * 0.5;
    vec2 rotatedXZ = rotate(vec2(vs_Pos.x, vs_Pos.z), swirlAngle);

    // Multi-octave Worley noise
    float noise = worleyFBM(rotatedXZ, u_Time, u_Octaves);

    // Height-based falloff
    float heightFactor = vs_Pos.y + 1.0;
    float heightMultiplier = heightFactor * heightFactor * 0.5;

    // Pulsing factor
    float pulse = 0.80 + 0.2 * sin(u_Time * 2.0 + vs_Pos.y * 5.0);

    // Mouse-based deformation
    // Calculate distance from vertex to mouse "ray" in 3D space
    vec3 mouseDirection = normalize(vec3(u_MousePos.x, u_MousePos.y, 1.0));
    float mouseInfluence = max(0.0, dot(normalize(vs_Pos.xyz), mouseDirection));
    mouseInfluence = pow(mouseInfluence, 4.0); 
    
    // Mouse strength 
    float mouseStrength = length(u_MousePos) * 2.0; // Stronger when mouse away from center

    vec4 modPos = vs_Pos;
    float displacement = noise * u_Strength * heightMultiplier * pulse;
    
    // Add mouse-based displacement
    displacement += mouseInfluence * mouseStrength * 0.3;
    
    fs_Height = displacement;

    modPos.xyz += vs_Nor.xyz * displacement;

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);

    vec4 modelposition = u_Model * modPos;
    fs_LightVec = lightPos - modelposition;

    gl_Position = u_ViewProj * modelposition;
}
