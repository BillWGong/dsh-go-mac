import { motion, useMotionValueEvent, useScroll, useSpring } from 'motion/react';
import { useRef, useState } from 'react';

const ROWS = [
  ['思考 · 决定调用 1 个工具', '1.8s'],
  ['运行 · mkdir -p /tmp/dsh-demo', '0.1s'],
  ['写入 · progress.py', '+28'],
  ['运行 · python3 progress.py', '0:03'],
  ['思考 · 20 行进度，0.5 秒一行', '0.0s']
];

function fmt(total: number) {
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = Math.floor(total % 60);
  return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function Console({ p }: { p: number }) {
  const steps = Math.round(122 * Math.min(1, p / 0.75));
  const files = Math.round(Math.min(1, Math.max(0, (p - 0.55) / 0.2)));
  const time = fmt((2 * 3600 + 60 + 57) * Math.min(1, p / 0.85));
  const active = p > 0.78 ? 4 : p > 0.62 ? 3 : p > 0.42 ? 2 : p > 0.2 ? 1 : 0;
  const diff = p > 0.58;

  return (
    <div className="console">
      <div className="console-head">
        <div className="lights"><i /><i /><i /></div>
        <span>run 001 · 做个下载进度条</span>
        <span className="right">{diff ? 'diff' : '进行中'}</span>
      </div>
      <div className="console-body">
        <div className="console-metrics">
          <div><b>{time}</b><span>用时</span></div>
          <div><b>{steps}</b><span>步骤</span></div>
          <div><b>{files}</b><span>改动文件</span></div>
        </div>
        <div className="console-tabs">
          {['轨迹', '改动', '文件', '进度', '上下文'].map((t, i) => (
            <span key={t} className={i === (diff ? 1 : 0) ? 'on' : ''}>{t}</span>
          ))}
        </div>
        {!diff && (
          <div className="console-rows">
            {ROWS.map(([label, t], i) => (
              <div key={label} className={`crow ${i <= active ? 'on' : ''}`}>
                <i>{i === 0 || i === 4 ? '◌' : i === 2 ? '+' : '›_'}</i>
                <b>{label}</b>
                <time>{t}</time>
              </div>
            ))}
          </div>
        )}
        <div className="console-diff" style={{ display: diff ? 'block' : 'none' }}>
          <span className="file">progress.py  +28 −1</span>
          <span style={{ color: 'var(--acid)' }}>+ for i in range(1, 21):</span><br />
          <span style={{ color: 'var(--acid)' }}>+     print(f"{'{'}i*5:3d{'}'}%")</span><br />
          <span style={{ color: 'var(--signal)' }}>- time.sleep(0.2)</span><br />
          <span style={{ color: 'var(--acid)' }}>+ time.sleep(0.5)</span>
        </div>
        <div className="console-spark">
          <div className="spark-label"><span>STEP TIMELINE</span><span>122 STEPS / 2:01:57</span></div>
          <svg viewBox="0 0 320 40" preserveAspectRatio="none">
            <motion.polyline
              points="0,31 10,28 20,30 30,22 40,25 50,18 60,21 70,14 80,17 90,12 100,15 110,9 120,12 130,8 140,11 150,6 160,9 170,7 180,10 190,5 200,8 210,6 220,9 230,4 240,7 250,5 260,8 270,3 280,6 290,4 300,7 310,2 320,5"
              fill="none" stroke="currentColor" strokeWidth="1"
              style={{ pathLength: Math.max(0.02, p) }}
            />
          </svg>
        </div>
        <div className={`console-toast ${p > 0.84 ? 'show' : ''}`}>
          <div><b>需要你确认</b><span>运行 python3 progress.py</span></div>
          <span className="yes">允许</span>
        </div>
      </div>
    </div>
  );
}

export function Surface() {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end end'] });
  const smooth = useSpring(scrollYProgress, { stiffness: 90, damping: 24, mass: 0.4 });
  const [p, setP] = useState(0);
  useMotionValueEvent(smooth, 'change', (v) => {
    const next = Math.round(v * 100) / 100;
    if (next !== p) setP(next);
  });

  return (
    <div id="surface">
      <section ref={ref} className="surface hidden lg:block">
        <div className="surface-sticky">
          <span className="surface-num" aria-hidden>02</span>
          <div className="shell surface-grid">
            <div className="surface-copy">
              <span className="kicker">02 / THE SURFACE</span>
              <h2>运行是<br /><em>一等公民</em>。</h2>
              <p>一轮任务结束，三个数先给你：用时、步骤、改动文件。下面五个页签：轨迹、改动、文件、进度、上下文。点「改动」就是 diff，点「轨迹」回看每一步。</p>
              <ul className="surface-list">
                <li><b>01</b> 每条思考、工具调用、耗时独立成行</li>
                <li><b>02</b> 审批和提问从消息流里浮出来</li>
                <li><b>03</b> 长任务里，扫一眼就知道状态</li>
              </ul>
            </div>
            <Console p={p} />
          </div>
        </div>
      </section>

      <section className="section lg:hidden">
        <div className="shell">
          <span className="kicker">02 / THE SURFACE</span>
          <h2 className="display" style={{ fontSize: 'clamp(40px,11vw,60px)', margin: '18px 0 20px' }}>运行是<br /><em className="serif signal">一等公民</em>。</h2>
          <p className="lead" style={{ justifySelf: 'start', marginBottom: 30 }}>一轮任务结束，三个数先给你：用时、步骤、改动文件。下面五个页签：轨迹、改动、文件、进度、上下文。</p>
          <Console p={1} />
        </div>
      </section>
    </div>
  );
}
