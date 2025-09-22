import {vec3, vec4} from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  color: [255,0,0,1],
  custom_vert: false,
  custom_frag: false,
  fireball_vert: false,
  fireball_frag: false,
  fireball_strength: 2.0,
  fireball_octaves: 4,
  fireball_alpha: 1.0,
  'Reset Fireball': resetFireballParameters,
  'Load Scene': loadScene, // A function pointer, essentially
};

let icosphere: Icosphere;
let square: Square;
let cube: Cube;
let prevCustomVert: boolean = false;
let prevCustomFrag: boolean = false;
let prevFireBallVert: boolean = false;
let prevFireBallFrag: boolean = false;
let prevFireBallStrength: number = 2.0;
let prevFireBallOctaves: number = 4;
let prevFireBallAlpha: number = 1.0;
let prevTesselations: number = 5;

// Mouse position tracking
let mouseX: number = 0.0;
let mouseY: number = 0.0;

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  cube = new Cube(vec3.fromValues(0, 0, 0));
  cube.create();
}

function resetFireballParameters() {
  controls.fireball_strength = 2.0;
  controls.fireball_octaves = 4;
  controls.fireball_alpha = 1.0;
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  const colorControl = gui.addColor(controls, 'color');
  
  // Add shader controls with mutual exclusion
  const customVertControl = gui.add(controls, 'custom_vert');
  const customFragControl = gui.add(controls, 'custom_frag');
  const fireballVertControl = gui.add(controls, 'fireball_vert');
  const fireballFragControl = gui.add(controls, 'fireball_frag');
  const fireballStrengthControl = gui.add(controls, 'fireball_strength', 0.0, 5.0);
  const fireballOctavesControl = gui.add(controls, 'fireball_octaves', 1, 8, 1);
  const fireballAlphaControl = gui.add(controls, 'fireball_alpha', 0.6, 1.0);
  const resetFireballButton = gui.add(controls, 'Reset Fireball');

  resetFireballButton.onChange(function() {
    if (
      controls.color[0] !== 255 ||
      controls.color[1] !== 0 ||
      controls.color[2] !== 0 ||
      controls.color[3] !== 1 ||
      controls.fireball_strength !== 1.0 ||
      controls.fireball_octaves !== 4 ||
      controls.fireball_alpha !== 0.5
    ) {
      controls.color = [255, 0, 0, 1];
      controls.fireball_strength = 2.0;
      controls.fireball_octaves = 4;
      controls.fireball_alpha = 1.0;
      prevFireBallStrength = 2.0;
      prevFireBallOctaves = 4;
      prevFireBallAlpha = 1.0;
      
      // Update the GUI display to show the reset values
      colorControl.updateDisplay();
      fireballStrengthControl.updateDisplay();
      fireballOctavesControl.updateDisplay();
      fireballAlphaControl.updateDisplay();
    }
  });

  // Set up mutual exclusion for vertex shaders
  customVertControl.onChange(function(value) {
    if (value) {
      controls.fireball_vert = false;
      fireballVertControl.updateDisplay();
    }
  });
  
  fireballVertControl.onChange(function(value) {
    if (value) {
      controls.custom_vert = false;
      customVertControl.updateDisplay();
    }
  });
  
  // Set up mutual exclusion for fragment shaders
  customFragControl.onChange(function(value) {
    if (value) {
      controls.fireball_frag = false;
      fireballFragControl.updateDisplay();
    }
  });
  
  fireballFragControl.onChange(function(value) {
    if (value) {
      controls.custom_frag = false;
      customFragControl.updateDisplay();
    }
  });
  
  gui.add(controls, 'Load Scene');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Add mouse event listeners for deformation
  canvas.addEventListener('mousemove', function(event) {
    const rect = canvas.getBoundingClientRect();
    // Normalize mouse coordinates to [-1, 1] range
    mouseX = ((event.clientX - rect.left) / canvas.width) * 2.0 - 1.0;
    mouseY = -(((event.clientY - rect.top) / canvas.height) * 2.0 - 1.0); // Flip Y
  });
  
  // Optional: Reset mouse position when mouse leaves canvas
  canvas.addEventListener('mouseleave', function(event) {
    mouseX = 0.0;
    mouseY = 0.0;
  });

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);

  // Track current shader program
  let currentShader: ShaderProgram;

  function updateShader() {
    let vertexShader = 'lambert';
    if (controls.fireball_vert) {
      vertexShader = 'fireball';
    } else if (controls.custom_vert) {
      vertexShader = 'custom';
    }

    let fragmentShader = 'lambert';
    if (controls.fireball_frag) {
      fragmentShader = 'fireball';
    } else if (controls.custom_frag) {
      fragmentShader = 'custom';
    }

    currentShader = new ShaderProgram([
      new Shader(gl.VERTEX_SHADER, require(`./shaders/${vertexShader}-vert.glsl`)),
      new Shader(gl.FRAGMENT_SHADER, require(`./shaders/${fragmentShader}-frag.glsl`)),
    ]);
  }

  // Initialize shader
  updateShader();
  
  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();

    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }
    // Check for shader toggle and update if needed
    if(controls.custom_vert != prevCustomVert)
    {
      prevCustomVert = controls.custom_vert;
      updateShader();
    } else if (controls.custom_frag != prevCustomFrag) {
      prevCustomFrag = controls.custom_frag;
      updateShader();
    } else if (controls.fireball_vert != prevFireBallVert) {
      prevFireBallVert = controls.fireball_vert;
      updateShader();
    } else if (controls.fireball_frag != prevFireBallFrag) {
      prevFireBallFrag = controls.fireball_frag;
      updateShader();
    }

    let time = performance.now() * 0.001; // time in seconds
    currentShader.setTime(time);
    currentShader.setFireballStrength(controls.fireball_strength);
    currentShader.setFireballOctaves(controls.fireball_octaves);
    currentShader.setFireballAlpha(controls.fireball_alpha);
    currentShader.setMousePos(mouseX, mouseY);

    renderer.render(camera, currentShader, [
      icosphere,
      // square,
      // cube,
    ], controls.color);
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
