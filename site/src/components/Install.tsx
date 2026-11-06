import { useState } from 'react';
import { BREW, LINKS } from '../lib/data';
import { Magnetic } from './Magnetic';
import { RevealTitle } from './Reveal';

export function Install() {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(BREW);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch { /* no clipboard */ }
  };

  return (
    <section className="section install" id="install">
      <div className="shell">
        <span className="kicker">05 / INSTALL</span>
        <RevealTitle>装上，<em>再评判</em>。</RevealTitle>
        <p className="install-note">
          1.0.20 的内置引擎是 DSH 0.2.2-rc.1。升级会替换运行时；对话、插件和设置保留，运行时里手动安装的依赖需要重装。
        </p>

        <div className="install-grid">
          <div className="terminal">
            <div className="term-head"><i /><i /><i /><span>zsh — dsh-go</span></div>
            <button className="copy" onClick={copy}>{copied ? '已复制' : '复制命令'}</button>
            <pre><code><span className="prompt">$</span> brew install --cask <span className="hl">BillWGong/tap/dsh-go-mac</span>{'\n\n'}<span className="dimc"># 或下载 DMG（Apple Silicon / macOS 12+）</span>{'\n'}<span className="prompt">$</span> open {LINKS.download}{'\n\n'}<span className="dimc"># 未签名构建被 Gatekeeper 拦住时</span>{'\n'}<span className="prompt">$</span> xattr -dr com.apple.quarantine "/Applications/DSH Go Mac.app"</code></pre>
            <div className="term-foot"><span>首次启动 · 选「连接官方 DSH」或「本机」</span><a href={LINKS.download} target="_blank" rel="noopener">下载 DMG ↗</a></div>
          </div>

          <div>
            <ol className="steps">
              <li><b>01</b><span>已在用官方 DSH：启动后选「连接官方 DSH」，不装运行时，读同一个 <code>~/.dsh</code>。</span></li>
              <li><b>02</b><span>想让 Mac 自己跑：选「本机」，安装约 750 MB 运行时。</span></li>
              <li><b>03</b><span>连远程：选「远程主机」，SSH 或 DSH Remote。</span></li>
            </ol>
            <a className="star-card" href={LINKS.original} target="_blank" rel="noopener">
              <span className="star-k"><span>最重要的事</span><span>STAR THE ORIGINAL ↗</span></span>
              <b>先给原作者点一个 star。</b>
              <p>这个仓库只是移植。没有 ccch1mneyyy 的 DSH Go，就没有 DSH Go Mac。</p>
              <span className="arrow">github.com/ccch1mneyyy/dsh-go →</span>
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
