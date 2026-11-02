import * as THREE from './vendor/three.module.min.js';

/**
 * A wireframe trace field: forty horizontal traces displaced by layered
 * sine fields, receding into the dark. It is the run, not a particle gag.
 */
export function initScene(canvas) {
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({canvas, alpha: true, antialias: true, powerPreference: 'high-performance'});
  } catch { return null; }

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(40, 1, .1, 40);
  camera.position.set(0, .55, 4.6);
  camera.lookAt(0, 0, 0);

  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
  renderer.setClearColor(0x000000, 0);
  renderer.outputColorSpace = THREE.SRGBColorSpace;

  const rows = 38, cols = 140, x0 = -4.4, x1 = 4.4, y0 = -2.5, y1 = 2.3;
  const positions = [], rowAttr = [];
  const push = (x, y, r) => { positions.push(x, y, 0); rowAttr.push(r); };

  for (let r = 0; r < rows; r++) {
    const y = y0 + (y1 - y0) * (r / (rows - 1));
    const rn = r / (rows - 1);
    for (let c = 0; c < cols; c++) {
      const xa = x0 + (x1 - x0) * (c / cols);
      const xb = x0 + (x1 - x0) * ((c + 1) / cols);
      push(xa, y, rn); push(xb, y, rn);
    }
  }
  for (let c = 0; c <= cols; c += 12) {
    const x = x0 + (x1 - x0) * (c / cols);
    for (let r = 0; r < rows - 1; r++) {
      const ya = y0 + (y1 - y0) * (r / (rows - 1));
      const yb = y0 + (y1 - y0) * ((r + 1) / (rows - 1));
      push(x, ya, -1); push(x, yb, -1);
    }
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setAttribute('aRow', new THREE.Float32BufferAttribute(rowAttr, 1));

  const uniforms = {
    uTime: {value: 0},
    uMouse: {value: new THREE.Vector2(0, 0)},
    uA: {value: new THREE.Color('#b8b0a2')},
    uB: {value: new THREE.Color('#ff5a2e')},
    uOpacity: {value: .22}
  };

  const mat = new THREE.ShaderMaterial({
    uniforms, transparent: true, depthWrite: false,
    vertexShader: `
      uniform float uTime;
      uniform vec2 uMouse;
      attribute float aRow;
      varying float vH;
      void main() {
        vec3 p = position;
        float d = length(p.xy);
        float w = sin(p.x * .95 + uTime * .32 + aRow * 2.4) * .18
                + sin(p.y * 1.55 - uTime * .21 + p.x * .32) * .10
                + sin(p.x * 2.6 - uTime * .5 + p.y * .7) * .035;
        w *= smoothstep(4.9, .3, d);
        w += uMouse.x * .035 * smoothstep(3.4, 0., d);
        p.z += w;
        vH = w;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(p, 1.);
      }
    `,
    fragmentShader: `
      uniform vec3 uA;
      uniform vec3 uB;
      uniform float uOpacity;
      varying float vH;
      void main() {
        float t = smoothstep(-.12, .20, vH);
        vec3 c = mix(uA, uB, t);
        gl_FragColor = vec4(c, uOpacity * (.35 + t * .65));
      }
    `
  });

  const lines = new THREE.LineSegments(geo, mat);
  lines.rotation.x = -.72;
  lines.position.y = -.1;
  scene.add(lines);

  const mouse = {x: 0, y: 0, tx: 0, ty: 0};
  let visible = true, raf = 0;
  const clock = new THREE.Clock();

  function resize() {
    const w = canvas.clientWidth || window.innerWidth;
    const h = canvas.clientHeight || window.innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }

  function frame() {
    raf = requestAnimationFrame(frame);
    if (!visible || document.hidden) return;
    const t = clock.getElapsedTime();
    uniforms.uTime.value = t;
    mouse.x += (mouse.tx - mouse.x) * .04;
    mouse.y += (mouse.ty - mouse.y) * .04;
    uniforms.uMouse.value.set(mouse.x, mouse.y);
    const sy = window.scrollY || 0;
    lines.rotation.z = Math.sin(t * .08) * .03;
    lines.position.y = -.1 + sy * .00035;
    camera.position.x = mouse.x * .28;
    camera.position.y = .55 + mouse.y * .10 + sy * .00018;
    camera.lookAt(0, 0, 0);
    renderer.render(scene, camera);
  }

  function onPointer(e) {
    mouse.tx = (e.clientX / window.innerWidth - .5) * 2;
    mouse.ty = -(e.clientY / window.innerHeight - .5) * 2;
  }

  window.addEventListener('resize', resize, {passive: true});
  window.addEventListener('pointermove', onPointer, {passive: true});
  const io = new IntersectionObserver(entries => { visible = entries[0]?.isIntersecting ?? true; }, {threshold: 0});
  io.observe(canvas);

  resize();
  frame();

  return {
    dispose() {
      cancelAnimationFrame(raf);
      io.disconnect();
      geo.dispose(); mat.dispose(); renderer.dispose();
      window.removeEventListener('resize', resize);
      window.removeEventListener('pointermove', onPointer);
    }
  };
}
