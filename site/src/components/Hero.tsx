import { motion, useMotionValue, useReducedMotion, useScroll, useSpring, useTransform } from 'motion/react';
import { Component, lazy, Suspense, useEffect, useRef, useState, type PointerEvent, type ReactNode } from 'react';
import { LINKS } from '../lib/data';
import { useMediaQuery } from '../lib/useMediaQuery';
import { Magnetic } from './Magnetic';
const TraceField = lazy(() => import('./TraceField'));

class SceneBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  componentDidCatch() {}
  render() { return this.state.failed ? null : this.props.children; }
}

function useWebGL() {
  const [ok, setOk] = useState(false);
  useEffect(() => {
    try {
      const c = document.createElement('canvas');
      setOk(!!(c.getContext('webgl2') || c.getContext('webgl')));
    } catch { setOk(false); }
  }, []);
  return ok;
}

function ProductCard({ ready }: { ready: boolean }) {
  const rx = useMotionValue(0), ry = useMotionValue(0);
  const rotateX = useSpring(rx, { stiffness: 120, damping: 18 });
  const rotateY = useSpring(ry, { stiffness: 120, damping: 18 });
  const onMove = (e: PointerEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    ry.set(((e.clientX - r.left) / r.width - 0.5) * 10);
    rx.set(-((e.clientY - r.top) / r.height - 0.5) * 8);
  };
  const reset = () => { rx.set(0); ry.set(0); };

  return (
    <div className="product-wrap">
      <motion.div
        className="product-card"
        style={{ rotateX, rotateY, transformStyle: 'preserve-3d' }}
        onPointerMove={onMove}
        onPointerLeave={reset}
        initial={{ opacity: 0, y: 50, rotateX: 8 }}
        animate={ready ? { opacity: 1, y: 0, rotateX: 0 } : {}}
        transition={{ duration: 1.2, delay: 0.55, ease: [0.22, 1, 0.36, 1] }}
      >
        <div className="product-top"><span className="ok" /> RUN 001 · COMPLETE <span>0:41</span></div>
        <div className="product-img">
          <img src="/images/app/hero-panel.jpg" alt="DSH Go Mac 运行详情：用时、步骤、改动文件与轨迹" width="700" height="1500" />
        </div>
        <div className="product-foot"><span>0:41 TOTAL</span><span>6 STEPS</span><span>1 FILE</span></div>
      </motion.div>
    </div>
  );
}

export function Hero({ ready }: { ready: boolean }) {
  const ref = useRef<HTMLElement>(null);
  const reduced = useReducedMotion();
  const desktop = useMediaQuery('(min-width: 900px)');
  const webgl = useWebGL();
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] });
  const y = useTransform(scrollYProgress, [0, 1], ['0%', '-8%']);
  const opacity = useTransform(scrollYProgress, [0, 0.75], [1, 0.15]);

  return (
    <section className="hero" id="top" ref={ref}>
      {desktop && !reduced && webgl && <SceneBoundary><Suspense fallback={null}><TraceField className="hero-canvas" /></Suspense></SceneBoundary>}
      <div className="shell">
        <motion.div className="hero-grid" style={{ y, opacity }}>
          <div className="hero-copy">
            <motion.p
              className="eyebrow"
              initial={{ opacity: 0, y: 10 }}
              animate={ready ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.8, delay: 0.45 }}
            >
              <span className="dot" /> DSH GO MAC — MACOS CLIENT / 001
            </motion.p>

            <h1 aria-label="把运行当成界面">
              <span className="line">
                <motion.span
                  initial={{ y: '112%' }}
                  animate={ready ? { y: '0%' } : {}}
                  transition={{ duration: 1.15, delay: 0.55, ease: [0.22, 1, 0.36, 1] }}
                >
                  把运行
                </motion.span>
              </span>
              <span className="line serif-line">
                <motion.span
                  initial={{ y: '112%' }}
                  animate={ready ? { y: '0%' } : {}}
                  transition={{ duration: 1.15, delay: 0.66, ease: [0.22, 1, 0.36, 1] }}
                >
                  当成<em>界面</em>。
                </motion.span>
              </span>
            </h1>

            <motion.p
              className="hero-sub"
              initial={{ opacity: 0, y: 18 }}
              animate={ready ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.9, delay: 0.85 }}
            >
              DeepSeek Harness 的第二个 macOS 客户端。同一个引擎，零迁移。
              它把一轮任务的全貌摆在你面前，而不是折进聊天记录。
            </motion.p>

            <motion.div
              className="hero-actions"
              initial={{ opacity: 0, y: 16 }}
              animate={ready ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.9, delay: 0.95 }}
            >
              <Magnetic>
                <a className="btn" href={LINKS.download} target="_blank" rel="noopener">下载 DMG <span>↗</span></a>
              </Magnetic>
              <a className="link" href="#install">或用 Homebrew 安装 <span>↓</span></a>
              <a className="link" href={LINKS.video} target="_blank" rel="noopener">看 10 秒录屏 ↗</a>
            </motion.div>

            <motion.div
              className="hero-meta"
              initial={{ opacity: 0 }}
              animate={ready ? { opacity: 1 } : {}}
              transition={{ duration: 0.9, delay: 1.05 }}
            >
              <span>macOS 12+</span><span>Apple Silicon</span><span>AGPL-3.0</span><span>v1.0.19</span><span>UPSTREAM 1.0.10</span>
            </motion.div>

            <motion.p
              className="star-line"
              initial={{ opacity: 0 }}
              animate={ready ? { opacity: 1 } : {}}
              transition={{ duration: 0.9, delay: 1.1 }}
            >
              <a href={LINKS.original} target="_blank" rel="noopener">★ 先给原作者点一个 star：ccch1mneyyy/dsh-go ↗</a>
            </motion.p>
          </div>

          <ProductCard ready={ready} />
        </motion.div>

        <div className="hero-bottom">
          <span className="scroll-cue">SCROLL TO INSPECT</span>
          <span className="rule" />
          <span>运行过程，一等公民</span>
        </div>
      </div>
    </section>
  );
}
