import { motion } from 'motion/react';
import { useEffect, useState } from 'react';

export function Loader({ onDone }: { onDone: () => void }) {
  const [n, setN] = useState(0);

  useEffect(() => {
    const started = performance.now();
    let raf = 0;
    const tick = (t: number) => {
      const p = Math.min(1, (t - started) / 900);
      setN(Math.round(p * 100));
      if (p < 1) raf = requestAnimationFrame(tick);
      else setTimeout(onDone, 180);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [onDone]);

  return (
    <motion.div className="loader" exit={{ y: '-100%' }} transition={{ duration: 0.85, ease: [0.76, 0, 0.24, 1] }}>
      <div className="loader-inner">
        <div className="loader-brand">
          <img src="/brand/glyph.svg" alt="" />
          DSH GO MAC — MACOS CLIENT<br />THE RUN IS THE INTERFACE
        </div>
        <div className="loader-count">{String(n).padStart(2, '0')}<sup style={{ fontSize: '.22em', verticalAlign: 'top' }}>%</sup></div>
      </div>
      <motion.div className="loader-bar" initial={{ scaleX: 0 }} animate={{ scaleX: n / 100 }} transition={{ ease: 'linear', duration: 0.1 }} />
    </motion.div>
  );
}
