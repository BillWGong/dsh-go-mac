import { AnimatePresence } from 'motion/react';
import Lenis from 'lenis';
import { useEffect, useState } from 'react';
import { Cursor } from './components/Cursor';
import { Engine } from './components/Engine';
import { Evidence } from './components/Evidence';
import { Footer } from './components/Footer';
import { Hero } from './components/Hero';
import { Install } from './components/Install';
import { Loader } from './components/Loader';
import { Native } from './components/Native';
import { Nav } from './components/Nav';
import { Rail } from './components/Rail';
import { Surface } from './components/Surface';
import { Ticker } from './components/Ticker';

export default function App() {
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced || window.matchMedia('(pointer: coarse)').matches) return;
    const lenis = new Lenis({ duration: 1.15, smoothWheel: true, wheelMultiplier: 1, touchMultiplier: 1.2 });
    let raf = 0;
    const loop = (time: number) => { lenis.raf(time); raf = requestAnimationFrame(loop); };
    raf = requestAnimationFrame(loop);
    return () => { cancelAnimationFrame(raf); lenis.destroy(); };
  }, []);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      const a = (e.target as HTMLElement).closest('a[href^="#"]') as HTMLAnchorElement | null;
      if (!a) return;
      const href = a.getAttribute('href');
      if (!href || href === '#') return;
      const target = document.querySelector(href);
      if (!target) return;
      e.preventDefault();
      const top = (target as HTMLElement).getBoundingClientRect().top + window.scrollY - 64;
      window.scrollTo({ top, behavior: 'smooth' });
    };
    document.addEventListener('click', onClick);
    return () => document.removeEventListener('click', onClick);
  }, []);

  return (
    <>
      <div className="grain" aria-hidden />
      <Cursor />
      <AnimatePresence>{loading && <Loader onDone={() => setLoading(false)} />}</AnimatePresence>
      <Rail />
      <Nav />
      <main>
        <Hero ready={!loading} />
        <Ticker />
        <Evidence />
        <Surface />
        <Engine />
        <Native />
        <Install />
        <Footer />
      </main>
    </>
  );
}
