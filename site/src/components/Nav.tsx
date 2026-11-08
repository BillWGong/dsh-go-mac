import { AnimatePresence, motion, useMotionValueEvent, useScroll, useSpring } from 'motion/react';
import { useEffect, useState } from 'react';
import { LINKS } from '../lib/data';
import { Magnetic } from './Magnetic';

const NAV = [
  ['证据', '#evidence'],
  ['界面', '#surface'],
  ['引擎', '#engine'],
  ['原生', '#native'],
  ['安装', '#install']
];

export function Nav() {
  const { scrollY, scrollYProgress } = useScroll();
  const progress = useSpring(scrollYProgress, { stiffness: 120, damping: 26, mass: 0.4 });
  const [scrolled, setScrolled] = useState(false);
  const [hidden, setHidden] = useState(false);
  const [open, setOpen] = useState(false);
  const [last, setLast] = useState(0);

  useMotionValueEvent(scrollY, 'change', (y) => {
    setScrolled(y > 40);
    setHidden(y > last && y > 480 && !open);
    setLast(y);
  });

  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [open]);

  return (
    <>
      <motion.header
        className={`nav ${scrolled ? 'scrolled' : ''}`}
        animate={{ y: hidden ? -90 : 0 }}
        transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
      >
        <a className="brand" href="#top" aria-label="DSH Go Mac 首页">
          <img src="/brand/glyph.svg" alt="DSH" />
          DSH GO MAC
        </a>
        <nav className="nav-links" aria-label="主导航">
          {NAV.map(([label, href]) => <a key={href} href={href}>{label}</a>)}
        </nav>
        <div className="nav-actions">
          <a className="nav-ghost" href={LINKS.github} target="_blank" rel="noopener">GitHub ↗</a>
          <Magnetic>
            <a className="btn small" href={LINKS.download} target="_blank" rel="noopener">下载 DMG <span>↗</span></a>
          </Magnetic>
        </div>
        <button
          id="menuBtn"
          className={`menu-btn ${open ? 'open' : ''}`}
          aria-label={open ? '关闭菜单' : '打开菜单'}
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
        >
          <span /><span />
        </button>
        <div className="nav-progress"><motion.i style={{ scaleX: progress }} /></div>
      </motion.header>

      <AnimatePresence>
        {open && (
          <motion.div
            className="menu"
            role="dialog"
            aria-modal="true"
            aria-label="导航菜单"
            initial={{ opacity: 0, y: -12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -12 }}
            transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
          >
            {NAV.map(([label, href], i) => (
              <motion.a
                key={href}
                href={href}
                onClick={() => setOpen(false)}
                initial={{ opacity: 0, y: 22 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.06 * i, duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
              >
                {label}
                <small>0{i + 1} — {['REAL RECORDING', 'THE RUN', 'ZERO MIGRATION', 'NATIVE', 'INSTALL'][i]}</small>
              </motion.a>
            ))}
            <motion.div className="menu-foot" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.35 }}>
              <a href={LINKS.download} target="_blank" rel="noopener">下载 DMG ↗</a>
              <a href={LINKS.github} target="_blank" rel="noopener">GitHub ↗</a>
              <span>macOS 12+ · APPLE SILICON · AGPL-3.0 · v1.0.21</span>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
