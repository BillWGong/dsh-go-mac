import { RevealTitle } from './Reveal';
import { motion, useScroll, useTransform } from 'motion/react';
import { useEffect, useRef, useState } from 'react';
import { PROOF } from '../lib/data';

function ProofCard({ item, index }: { item: (typeof PROOF)[number]; index: number }) {
  return (
    <article className="proof">
      <div className="proof-meta">
        <span>{item.no} / {item.label}</span>
        <span>{item.meta}</span>
      </div>
      <div className="proof-media">
        <img
          src={item.src}
          alt={item.alt}
          width={index === 0 ? 1000 : index === 1 ? 2360 : 1700}
          height={index === 0 ? 695 : index === 1 ? 1320 : 1400}
          loading={index === 0 ? 'eager' : 'lazy'}
        />
      </div>
      <p>{item.caption}</p>
    </article>
  );
}

export function Evidence() {
  const ref = useRef<HTMLDivElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const [distance, setDistance] = useState(0);
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end end'] });
  const x = useTransform(scrollYProgress, [0, 1], [0, -distance]);

  useEffect(() => {
    const measure = () => {
      const track = trackRef.current;
      if (!track) return;
      setDistance(Math.max(0, track.scrollWidth - window.innerWidth + 56));
    };
    measure();
    const ro = new ResizeObserver(measure);
    if (trackRef.current) ro.observe(trackRef.current);
    window.addEventListener('resize', measure);
    return () => { ro.disconnect(); window.removeEventListener('resize', measure); };
  }, []);

  return (
    <section className="section evidence" id="evidence">
      <div className="shell">
        <div className="section-head">
          <div>
            <span className="kicker">01 / EVIDENCE</span>
            <RevealTitle>真实，<em>没有加速</em>。</RevealTitle>
          </div>
          <p className="lead">一个需要工具调用的真实任务，和它跑完之后留下的东西。录屏没有剪辑，截图没有摆拍。</p>
        </div>
      </div>

      <div ref={ref} className="hidden lg:block" style={{ height: '300vh' }}>
        <div className="evidence-pin">
          <motion.div ref={trackRef} className="evidence-track" style={{ x }}>
            {PROOF.map((item, i) => <ProofCard key={item.no} item={item} index={i} />)}
          </motion.div>
        </div>
      </div>

      <div className="evidence-mobile">
        {PROOF.map((item, i) => <ProofCard key={item.no} item={item} index={i} />)}
      </div>
    </section>
  );
}
