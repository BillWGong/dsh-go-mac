import { motion } from 'motion/react';
import { useEffect, useRef, useState, type ReactNode } from 'react';

function useEnter<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [entered, setEntered] = useState(false);
  useEffect(() => {
    const check = () => {
      const el = ref.current;
      if (!el || entered) return;
      if (el.getBoundingClientRect().top < window.innerHeight * 0.9) setEntered(true);
    };
    check();
    window.addEventListener('scroll', check, { passive: true });
    window.addEventListener('resize', check);
    return () => { window.removeEventListener('scroll', check); window.removeEventListener('resize', check); };
  }, [entered]);
  return { ref, entered };
}

export function Reveal({ children, className = '', delay = 0, y = 26 }: { children: ReactNode; className?: string; delay?: number; y?: number }) {
  const { ref, entered: inView } = useEnter<HTMLDivElement>();
  return (
    <motion.div
      ref={ref}
      className={className}
      initial={{ opacity: 0, y }}
      animate={inView ? { opacity: 1, y: 0 } : {}}
      transition={{ duration: 0.95, delay, ease: [0.22, 1, 0.36, 1] }}
    >
      {children}
    </motion.div>
  );
}

export function RevealTitle({ children, className = '', id }: { children: ReactNode; className?: string; id?: string }) {
  const { ref, entered: inView } = useEnter<HTMLHeadingElement>();
  return (
    <motion.h2
      id={id}
      ref={ref}
      className={className}
      initial={{ opacity: 0, y: 26, clipPath: 'inset(0 0 100% 0)' }}
      animate={inView ? { opacity: 1, y: 0, clipPath: 'inset(0 0 0% 0)' } : {}}
      transition={{ duration: 1.15, ease: [0.22, 1, 0.36, 1] }}
    >
      {children}
    </motion.h2>
  );
}
