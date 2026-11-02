import { RevealTitle } from './Reveal';
import { Spotlight } from './Spotlight';
import { Reveal } from './Reveal';

export function Native() {
  return (
    <section className="section native" id="native">
      <div className="shell">
        <div className="section-head">
          <div>
            <span className="kicker">04 / NATIVE</span>
            <RevealTitle>没有壳。<br /><em>只有 macOS</em>。</RevealTitle>
          </div>
          <p className="lead">Flutter 界面、Swift 平台层、原生 Node 引擎。没有 Electron，没有内嵌浏览器。</p>
        </div>

        <div className="native-grid">
          <Spotlight className="a">
            <div>
              <span className="no">01 / APPROVALS</span>
              <h3>通知里就能审批</h3>
              <p>一轮结束、等待确认，系统通知上直接「允许 / 拒绝」，点一下回到对话。不是网页里的按钮。</p>
            </div>
            <div className="notify">
              <div className="notify-head"><span>DSH GO MAC</span><b>现在</b></div>
              <div className="notify-body"><span className="logo">D</span> 需要你确认 · 运行 python3 progress.py</div>
              <div className="notify-actions"><span>允许</span><span>拒绝</span></div>
            </div>
          </Spotlight>

          <Spotlight className="b">
            <span className="no">02 / FILES · PDF · VOICE</span>
            <h3>文件、PDF、语音、桌宠</h3>
            <p>打开、另存、PDFKit 预览、SFSpeechRecognizer、无边框桌宠浮窗，全走 macOS API。</p>
          </Spotlight>

          <Spotlight className="c">
            <span className="no">03 / MOTION</span>
            <h3>动效是功能</h3>
            <p>思考胶囊呼吸、工具行滑入、折叠连续展开。长任务里，扫一眼就知道状态。</p>
          </Spotlight>
        </div>

        <Reveal className="native-shot">
          <div className="native-shot-meta"><span>4.1 FLASH · THIS MAC</span><span>REAL RUN / 0:41</span></div>
          <img src="/images/app/app-dark.jpg" alt="DSH Go Mac 的一次真实运行" width="2360" height="1320" loading="lazy" />
        </Reveal>
      </div>
    </section>
  );
}
