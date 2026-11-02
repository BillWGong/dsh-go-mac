import { useEffect, useState } from 'react';

const ITEMS = [
  ['evidence', '01 — EVIDENCE'],
  ['surface', '02 — SURFACE'],
  ['engine', '03 — ENGINE'],
  ['native', '04 — NATIVE'],
  ['install', '05 — INSTALL']
];

export function Rail() {
  const [active, setActive] = useState('');
  useEffect(() => {
    const els = ITEMS.map(([id]) => document.getElementById(id)).filter(Boolean) as HTMLElement[];
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => { if (en.isIntersecting) setActive(en.target.id); });
    }, { rootMargin: '-45% 0px -45% 0px', threshold: 0 });
    els.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  return (
    <aside className={`rail ${active === 'evidence' ? 'hide' : ''}`} aria-label="章节">
      <span className="rail-line" />
      {ITEMS.map(([id, label]) => (
        <a key={id} href={`#${id}`} className={active === id ? 'on' : ''}>{label}</a>
      ))}
    </aside>
  );
}
