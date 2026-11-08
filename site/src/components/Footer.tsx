import { LINKS } from '../lib/data';

export function Footer() {
  return (
    <footer className="footer">
      <div className="shell">
        <div className="footer-top">
          <div>非官方社区项目，与 DeepSeek 无隶属关系。<br />基于 <a href={LINKS.original} target="_blank" rel="noopener" style={{ color: 'var(--bone)' }}>ccch1mneyyy/dsh-go</a>（AGPL-3.0）。</div>
          <div className="footer-links">
            <a href={LINKS.github} target="_blank" rel="noopener">GitHub ↗</a>
            <a href={LINKS.releases} target="_blank" rel="noopener">Releases ↗</a>
            <a href={LINKS.issues} target="_blank" rel="noopener">Issues ↗</a>
            <a href={LINKS.video} target="_blank" rel="noopener">Demo ↗</a>
          </div>
        </div>
        <div className="footer-word" aria-hidden>DSH GO MAC</div>
        <div className="footer-bottom">
          <span>© 2026 DSH GO MAC · BUILT WITH FLUTTER + SWIFT</span>
          <span>DESIGNED FOR THE RUN · v1.0.21</span>
        </div>
      </div>
    </footer>
  );
}
