import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { useMemo, useRef } from 'react';
import * as THREE from 'three';

function TraceLines() {
  const ref = useRef<THREE.LineSegments>(null!);
  const { pointer } = useThree();
  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uMouse: { value: new THREE.Vector2(0, 0) },
      uA: { value: new THREE.Color('#b8b0a2') },
      uB: { value: new THREE.Color('#ff5a2e') },
      uOpacity: { value: 0.22 }
    }),
    []
  );

  const geometry = useMemo(() => {
    const rows = 38, cols = 140, x0 = -4.4, x1 = 4.4, y0 = -2.5, y1 = 2.3;
    const positions: number[] = [], rowAttr: number[] = [];
    const push = (x: number, y: number, r: number) => {
      positions.push(x, y, 0); rowAttr.push(r);
    };
    for (let r = 0; r < rows; r++) {
      const y = y0 + (y1 - y0) * (r / (rows - 1));
      const rn = r / (rows - 1);
      for (let c = 0; c < cols; c++) {
        push(x0 + (x1 - x0) * (c / cols), y, rn);
        push(x0 + (x1 - x0) * ((c + 1) / cols), y, rn);
      }
    }
    for (let c = 0; c <= cols; c += 12) {
      const x = x0 + (x1 - x0) * (c / cols);
      for (let r = 0; r < rows - 1; r++) {
        push(x, y0 + (y1 - y0) * (r / (rows - 1)), -1);
        push(x, y0 + (y1 - y0) * ((r + 1) / (rows - 1)), -1);
      }
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    g.setAttribute('aRow', new THREE.Float32BufferAttribute(rowAttr, 1));
    return g;
  }, []);

  const material = useMemo(
    () =>
      new THREE.ShaderMaterial({
        uniforms,
        transparent: true,
        depthWrite: false,
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
      }),
    [uniforms]
  );

  useFrame((state) => {
    const t = state.clock.elapsedTime;
    uniforms.uTime.value = t;
    uniforms.uMouse.value.set(pointer.x, pointer.y);
    if (ref.current) {
      const sy = window.scrollY || 0;
      ref.current.rotation.z = Math.sin(t * 0.08) * 0.03;
      ref.current.rotation.x = -0.72 + sy * 0.00002;
      ref.current.position.y = -0.1 + sy * 0.00035;
    }
  });

  return <lineSegments ref={ref} geometry={geometry} material={material} rotation={[-0.72, 0, 0]} position={[0, -0.1, 0]} />;
}

export default function TraceField({ className = '' }: { className?: string }) {
  return (
    <div className={className}>
      <Canvas
        dpr={[1, 1.6]}
        gl={{ antialias: true, alpha: true, powerPreference: 'high-performance' }}
        camera={{ fov: 40, position: [0, 0.55, 4.6], near: 0.1, far: 40 }}
        onCreated={({ gl }) => gl.setClearColor(0x000000, 0)}
      >
        <TraceLines />
      </Canvas>
    </div>
  );
}
