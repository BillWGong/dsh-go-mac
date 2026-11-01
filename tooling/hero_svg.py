#!/usr/bin/env python3
"""Generate the animated README hero (light/dark) as self-contained SVG."""
from pathlib import Path

DARK = dict(
    bg0="#07090F", bg1="#0B1020", grid="#FFFFFF", grid_op=".035",
    panel="#0D1322", panel2="#111A2E", line="#26334D",
    ink="#F2F6FF", muted="#7F90AC", dim="#5B6B85",
    accent="#7AA2FF", accent2="#A78BFA", green="#34D399", red="#FF6B6B",
    bubble="#1A2A4A", bubble_line="#2E4A7A", toast="#111C31",
)
LIGHT = dict(
    bg0="#F7F9FE", bg1="#EDF2FB", grid="#0B1220", grid_op=".045",
    panel="#FFFFFF", panel2="#F3F6FC", line="#DCE4F2",
    ink="#0C1424", muted="#5C6C86", dim="#8595AC",
    accent="#3B6EF5", accent2="#7C5CFA", green="#0EA371", red="#E5484D",
    bubble="#EAF1FF", bubble_line="#C9D9F8", toast="#FFFFFF",
)

def svg(p):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="600" viewBox="0 0 1200 600" role="img" aria-label="DSH Go Mac — 把运行当成界面">
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{p['bg0']}"/><stop offset="1" stop-color="{p['bg1']}"/>
  </linearGradient>
  <linearGradient id="accent" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="{p['accent']}"/><stop offset="1" stop-color="{p['accent2']}"/>
  </linearGradient>
  <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
    <path d="M40 0H0V40" fill="none" stroke="{p['grid']}" stroke-opacity="{p['grid_op']}"/>
  </pattern>
  <filter id="win" x="-30%" y="-30%" width="160%" height="160%">
    <feDropShadow dx="0" dy="18" stdDeviation="28" flood-color="#000" flood-opacity=".38"/>
  </filter>
  <filter id="toast" x="-30%" y="-30%" width="160%" height="160%">
    <feDropShadow dx="0" dy="8" stdDeviation="14" flood-color="#000" flood-opacity=".30"/>
  </filter>
</defs>

<rect width="1200" height="600" fill="url(#bg)"/>
<rect width="1200" height="600" fill="url(#grid)"/>
<ellipse cx="930" cy="120" rx="360" ry="240" fill="{p['accent']}" opacity=".10"/>
<ellipse cx="520" cy="560" rx="320" ry="200" fill="{p['accent2']}" opacity=".08"/>

<!-- left: wordmark -->
<text x="64" y="76" fill="{p['muted']}" font-family="-apple-system, 'SF Pro Text', 'PingFang SC', Arial, sans-serif" font-size="11" letter-spacing="3.2">DSH GO MAC · MACOS</text>
<text x="61" y="164" fill="{p['ink']}" font-family="-apple-system, 'SF Pro Display', 'PingFang SC', Arial, sans-serif" font-size="62" font-weight="700" letter-spacing="-1.6">把「运行」</text>
<text x="61" y="234" fill="{p['ink']}" font-family="-apple-system, 'SF Pro Display', 'PingFang SC', Arial, sans-serif" font-size="62" font-weight="700" letter-spacing="-1.6">当成<tspan fill="url(#accent)">界面</tspan>。</text>
<text x="64" y="280" fill="{p['muted']}" font-family="-apple-system, 'PingFang SC', 'Helvetica Neue', Arial, sans-serif" font-size="17">DeepSeek Harness 的第二个 macOS 客户端。</text>
<text x="64" y="308" fill="{p['dim']}" font-family="-apple-system, 'PingFang SC', 'Helvetica Neue', Arial, sans-serif" font-size="17">同一个引擎，零迁移。过程信息、通知审批、原生动效。</text>

<rect x="64" y="344" width="72" height="3" rx="1.5" fill="url(#accent)"/>
<text x="64" y="384" fill="{p['muted']}" font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="12.5">run 001 · macOS port</text>
<g font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="13.5">
  <text x="64" y="408" fill="{p['dim']}">time</text>
  <text x="110" y="408" fill="{p['accent']}">0:09</text>
  <text x="176" y="408" fill="{p['dim']}">steps</text>
  <text x="226" y="408" fill="{p['ink']}">4</text>
  <text x="264" y="408" fill="{p['dim']}">files</text>
  <text x="308" y="408" fill="{p['ink']}">1</text>
  <text x="352" y="408" fill="{p['green']}">●</text>
</g>
<g font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="10" fill="{p['muted']}">
  <rect x="64" y="448" width="96" height="26" rx="13" fill="{p['panel2']}" stroke="{p['line']}"/>
  <circle cx="82" cy="461" r="3" fill="{p['accent']}"/>
  <text x="94" y="465">官方 DSH</text>
  <rect x="172" y="448" width="84" height="26" rx="13" fill="{p['panel2']}" stroke="{p['line']}"/>
  <circle cx="190" cy="461" r="3" fill="{p['green']}"/>
  <text x="202" y="465">内置引擎</text>
  <rect x="268" y="448" width="66" height="26" rx="13" fill="{p['panel2']}" stroke="{p['line']}"/>
  <circle cx="286" cy="461" r="3" fill="{p['accent2']}"/>
  <text x="298" y="465">远程</text>
</g>

<!-- window -->
<g filter="url(#win)">
  <rect x="600" y="84" width="540" height="432" rx="18" fill="{p['panel']}" stroke="{p['line']}" stroke-width="1"/>
</g>
<rect x="600" y="84" width="540" height="38" rx="18" fill="{p['panel2']}"/>
<rect x="600" y="104" width="540" height="18" fill="{p['panel2']}"/>
<circle cx="620" cy="103" r="5.5" fill="#FF5F57"/><circle cx="638" cy="103" r="5.5" fill="#FEBC2E"/><circle cx="656" cy="103" r="5.5" fill="#28C840"/>
<text x="676" y="107" fill="{p['muted']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="10.5">做个下载进度条</text>
<text x="1104" y="107" fill="{p['dim']}" font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10">v1.0.17</text>

<!-- chat column -->
<g id="scene">
  <!-- active step indicator -->
  <rect x="610" y="258" width="2" height="18" rx="1" fill="{p['accent']}" opacity=".9">
    <animate attributeName="y" values="258;284;310;336;258" keyTimes="0;.25;.5;.75;1" dur="4.8s" repeatCount="indefinite"/>
  </rect>
  <!-- user bubble -->
  <g>
    <rect x="616" y="142" width="300" height="64" rx="12" fill="{p['bubble']}" stroke="{p['bubble_line']}"/>
    <text x="630" y="164" fill="{p['ink']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="11.5">做个下载进度条：写一个 <tspan font-family="ui-monospace, Menlo, monospace" fill="{p['accent']}">progress.py</tspan>，</text>
    <text x="630" y="181" fill="{p['ink']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="11.5">每 0.5 秒打印一行，跑完告诉我结果。</text>
  </g>

  <!-- thinking pill -->
  <g>
    <rect x="616" y="218" width="300" height="26" rx="13" fill="{p['panel2']}" stroke="{p['line']}"/>
    <circle cx="630" cy="231" r="3" fill="{p['accent2']}">
      <animate attributeName="opacity" values=".3;1;.3" dur="1.6s" repeatCount="indefinite"/>
    </circle>
    <text x="640" y="235" fill="{p['muted']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="10.5">思考 · 决定调用 1 个工具</text>
    <text x="898" y="235" fill="{p['dim']}" font-family="ui-monospace, Menlo, monospace" font-size="9.5" text-anchor="end">1.8s</text>
    <rect x="616" y="246" width="300" height="2" rx="1" fill="{p['line']}"/>
    <rect x="616" y="246" width="120" height="2" rx="1" fill="url(#accent)">
      <animate attributeName="opacity" values=".55;1;.55" dur="2.4s" repeatCount="indefinite"/>
    </rect>
  </g>

  <!-- rows -->
  <g>
    <rect x="616" y="252" width="300" height="1" fill="{p['line']}"/>
    <text x="620" y="274" fill="{p['accent']}" font-family="ui-monospace, Menlo, monospace" font-size="10">›_</text>
    <text x="640" y="274" fill="{p['ink']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="10.5">运行 · mkdir -p /tmp/dsh-demo</text>
    <text x="902" y="274" fill="{p['dim']}" font-family="ui-monospace, Menlo, monospace" font-size="9" text-anchor="end">0.1s</text>
  </g>
  <g>
    <text x="620" y="300" fill="{p['green']}" font-family="ui-monospace, Menlo, monospace" font-size="10">+</text>
    <text x="640" y="300" fill="{p['ink']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="10.5">写入 · progress.py</text>
    <text x="902" y="300" fill="{p['green']}" font-family="ui-monospace, Menlo, monospace" font-size="9" text-anchor="end">+28</text>
  </g>
  <g>
    <text x="620" y="326" fill="{p['accent']}" font-family="ui-monospace, Menlo, monospace" font-size="10">›_</text>
    <text x="640" y="326" fill="{p['ink']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="10.5">运行 · python3 progress.py</text>
    <text x="902" y="326" fill="{p['dim']}" font-family="ui-monospace, Menlo, monospace" font-size="9" text-anchor="end">0:03</text>
  </g>
  <g>
    <rect x="632" y="340" width="200" height="3" rx="1.5" fill="{p['line']}"/>
    <rect x="632" y="340" width="168" height="3" rx="1.5" fill="url(#accent)">
      <animate attributeName="opacity" values=".55;1;.55" dur="2.4s" repeatCount="indefinite"/>
    </rect>
    <text x="840" y="346" fill="{p['muted']}" font-family="ui-monospace, Menlo, monospace" font-size="8.5">18%</text>
  </g>
</g>

<!-- right detail panel -->
<g id="panel">
  <rect x="930" y="122" width="1" height="380" fill="{p['line']}"/>
  <text x="946" y="146" fill="{p['ink']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="11.5" font-weight="600">对话详情</text>
  <text x="946" y="166" fill="{p['muted']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="9.5">共 1 轮 · 进行中</text>

  <!-- metrics -->
  <g font-family="ui-monospace, Menlo, monospace">
    <text x="946" y="200" fill="{p['ink']}" font-size="21" font-weight="600">0:09</text>
    <text x="946" y="216" fill="{p['dim']}" font-size="8.5" font-family="-apple-system, 'PingFang SC', Arial, sans-serif">用时</text>
    <text x="1010" y="200" fill="{p['ink']}" font-size="21" font-weight="600">4</text>
    <text x="1010" y="216" fill="{p['dim']}" font-size="8.5" font-family="-apple-system, 'PingFang SC', Arial, sans-serif">步骤</text>
    <text x="1062" y="200" fill="{p['ink']}" font-size="21" font-weight="600">1</text>
    <text x="1062" y="216" fill="{p['dim']}" font-size="8.5" font-family="-apple-system, 'PingFang SC', Arial, sans-serif">改动文件</text>
  </g>

  <!-- tabs -->
  <rect x="942" y="232" width="176" height="24" rx="12" fill="{p['panel2']}"/>
  <rect id="tabhi" x="946" y="235" width="30" height="18" rx="9" fill="{p['line']}">
    <animate attributeName="x" values="946;946;1000;1000" keyTimes="0;.62;.68;1" dur="12s" repeatCount="indefinite"/>
  </rect>
  <g fill="{p['muted']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="8.5">
    <text x="961" y="247" text-anchor="middle">轨迹</text>
    <text x="1000" y="247" text-anchor="middle">改动</text>
    <text x="1040" y="247" text-anchor="middle">文件</text>
    <text x="1080" y="247" text-anchor="middle">进度</text>
    <text x="1112" y="247" text-anchor="middle">上下文</text>
  </g>

  <!-- round card -->
  <rect x="940" y="268" width="184" height="148" rx="10" fill="{p['panel2']}" stroke="{p['line']}"/>
  <text x="952" y="286" fill="{p['muted']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="8.5">第 1 轮 · 进行中</text>
  <text x="1112" y="286" fill="{p['dim']}" font-family="ui-monospace, Menlo, monospace" font-size="8" text-anchor="end">0:09</text>
  <g font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="8.5" fill="{p['muted']}">
    <text x="952" y="308">思考 · 决定调用 1 个工具</text><text x="1112" y="308" text-anchor="end">1.8s</text>
    <text x="952" y="326">运行 · mkdir -p /tmp/dsh-demo</text><text x="1112" y="326" text-anchor="end">0.1s</text>
    <text x="952" y="344">写入 · progress.py</text><text x="1112" y="344" text-anchor="end">+28</text>
    <text x="952" y="362">运行 · python3 progress.py</text><text x="1112" y="362" text-anchor="end">0:03</text>
  </g>
  <rect x="952" y="378" width="160" height="2" rx="1" fill="{p['line']}"/>
  <rect x="952" y="378" width="132" height="2" rx="1" fill="url(#accent)">
    <animate attributeName="opacity" values=".55;1;.55" dur="2.4s" repeatCount="indefinite"/>
  </rect>
</g>

<!-- approval toast -->
<g id="toast" filter="url(#toast)">
  <g>
    <animateTransform attributeName="transform" type="translate" values="0 0;0 -2;0 0" keyTimes="0;.5;1" dur="4s" repeatCount="indefinite"/>
    <rect x="616" y="438" width="516" height="58" rx="14" fill="{p['toast']}" stroke="{p['line']}"/>
    <circle cx="636" cy="460" r="8" fill="{p['accent']}" opacity=".18"/>
    <text x="633" y="464" fill="{p['accent']}" font-family="ui-monospace, Menlo, monospace" font-size="9">!</text>
    <text x="654" y="456" fill="{p['ink']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="10" font-weight="600">需要你确认</text>
    <text x="654" y="472" fill="{p['muted']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="9">运行 python3 progress.py</text>
    <rect x="1004" y="452" width="52" height="24" rx="12" fill="{p['accent']}"/>
    <text x="1030" y="468" fill="#08101F" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="9" font-weight="600" text-anchor="middle">允许</text>
    <rect x="1062" y="452" width="52" height="24" rx="12" fill="none" stroke="{p['line']}"/>
    <text x="1088" y="468" fill="{p['muted']}" font-family="-apple-system, 'PingFang SC', Arial, sans-serif" font-size="9" text-anchor="middle">拒绝</text>
  </g>
</g>

</svg>'''

root = Path(__file__).resolve().parents[1] / "docs" / "images"
for name, palette in (("hero-dark", DARK), ("hero-light", LIGHT)):
    (root / f"{name}.svg").write_text(svg(palette), encoding="utf-8")
    print("wrote", name)
