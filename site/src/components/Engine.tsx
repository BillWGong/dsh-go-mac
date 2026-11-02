import { RevealTitle } from './Reveal';
import { motion, useScroll, useTransform } from 'motion/react';
import { useRef, useState } from 'react';
import { HOSTS } from '../lib/data';

export function Engine() {
  const [host, setHost] = useState<(typeof HOSTS)[number]['id']>('official');
  const ref = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] });
  const y = useTransform(scrollYProgress, [0, 1], [30, -30]);
  const active = HOSTS.find((h) => h.id === host)!;

  return (
    <section ref={ref} className="section engine" id="engine">
      <div className="shell">
        <div className="section-head">
          <div>
            <span className="kicker">03 / ZERO MIGRATION</span>
            <RevealTitle>同一个引擎，<br /><em>零迁移</em>。</RevealTitle>
          </div>
          <p className="lead">它不替换你的引擎。首次启动检测本机官方 DSH，连上后读的还是同一个 <code>~/.dsh</code>。</p>
        </div>

        <div className="engine-body">
          <div>
            <div className="hosts" role="tablist" aria-label="主机模式">
              {HOSTS.map((h) => (
                <button
                  key={h.id}
                  className={`host ${h.id === host ? 'on' : ''}`}
                  role="tab"
                  aria-selected={h.id === host}
                  onClick={() => setHost(h.id)}
                >
                  <span className="no">{h.no}</span>
                  <span><b>{h.title}</b><span>{h.sub}</span></span>
                  <span className="arr">↗</span>
                </button>
              ))}
            </div>
            <p className="host-note">{active.note}</p>
          </div>

          <div className="engine-visual">
            <motion.div className="engine-frame" style={{ y }} initial={{ opacity: 0, rotateY: -7 }} whileInView={{ opacity: 1, rotateY: -2 }} viewport={{ once: true, margin: '-15%' }} transition={{ duration: 1.1, ease: [0.22, 1, 0.36, 1] }}>
              <span className="cross tl" /><span className="cross br" />
              <img src="/images/app/new-chat.jpg" alt="DSH Go Mac 新对话与主机状态" width="1700" height="1400" loading="lazy" />
            </motion.div>
            <svg className="beam" viewBox="0 0 600 260" fill="none" aria-hidden>
              <motion.path
                d="M20 230 C160 230 170 60 300 60 S470 220 580 40"
                stroke="#ff4a1c" strokeWidth="1" strokeDasharray="4 6"
                initial={{ pathLength: 0, opacity: 0 }}
                whileInView={{ pathLength: 1, opacity: .55 }}
                viewport={{ once: true, margin: '-20%' }}
                transition={{ duration: 1.8, ease: 'easeInOut' }}
              />
            </svg>
          </div>
        </div>
      </div>
    </section>
  );
}
