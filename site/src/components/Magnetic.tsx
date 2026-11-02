import { motion, useMotionValue, useSpring } from 'motion/react';
import type { ReactNode, PointerEvent } from 'react';

export function Magnetic({ children, className = '', strength = 14 }: { children: ReactNode; className?: string; strength?: number }) {
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const sx = useSpring(x, { stiffness: 220, damping: 18, mass: 0.4 });
  const sy = useSpring(y, { stiffness: 220, damping: 18, mass: 0.4 });

  const onMove = (e: PointerEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    x.set(((e.clientX - r.left - r.width / 2) / r.width) * strength);
    y.set(((e.clientY - r.top - r.height / 2) / r.height) * strength);
  };
  const reset = () => { x.set(0); y.set(0); };

  return (
    <motion.div className={className} style={{ x: sx, y: sy }} onPointerMove={onMove} onPointerLeave={reset}>
      {children}
    </motion.div>
  );
}
