import { motion, useMotionValue, useReducedMotion, useSpring } from 'motion/react';
import { useEffect, useState } from 'react';

export function Cursor() {
  const reduced = useReducedMotion();
  const x = useMotionValue(-100);
  const y = useMotionValue(-100);
  const sx = useSpring(x, { stiffness: 500, damping: 40, mass: 0.2 });
  const sy = useSpring(y, { stiffness: 500, damping: 40, mass: 0.2 });
  const [grow, setGrow] = useState(false);

  useEffect(() => {
    if (reduced) return;
    const move = (e: PointerEvent) => {
      x.set(e.clientX); y.set(e.clientY);
      const el = e.target as HTMLElement;
      setGrow(!!el.closest('a,button,[data-magnetic]'));
    };
    window.addEventListener('pointermove', move, { passive: true });
    return () => window.removeEventListener('pointermove', move);
  }, [reduced, x, y]);

  if (reduced) return null;
  return <motion.div className={`cursor ${grow ? 'grow' : ''}`} style={{ x: sx, y: sy }} />;
}
