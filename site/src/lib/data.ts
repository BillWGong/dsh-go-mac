export const LINKS = {
  download: 'https://github.com/BillWGong/dsh-go-mac/releases/latest',
  github: 'https://github.com/BillWGong/dsh-go-mac',
  releases: 'https://github.com/BillWGong/dsh-go-mac/releases',
  issues: 'https://github.com/BillWGong/dsh-go-mac/issues',
  original: 'https://github.com/ccch1mneyyy/dsh-go',
  brewTap: 'https://github.com/BillWGong/homebrew-tap',
  video: 'https://www.bilibili.com/video/BV1njxJ6WE59/',
  site: 'https://dsh.billw.top/'
};

export const BREW = 'brew install --cask BillWGong/tap/dsh-go-mac';

export const HOSTS = [
  {
    id: 'official',
    no: '01',
    title: '连接官方 DSH',
    sub: '对话、模型、插件原样都在',
    note: '不迁移、不复制。读的还是 ~/.dsh，官方客户端随时可以继续用。'
  },
  {
    id: 'bundled',
    no: '02',
    title: '内置引擎',
    sub: 'Node 24 + DSH，装进 App',
    note: 'Node 24 + DSH 装进 App。首次使用安装约 750 MB 运行时，之后离线也能起引擎。'
  },
  {
    id: 'remote',
    no: '03',
    title: '远程主机',
    sub: 'SSH / DSH Remote',
    note: '同一套界面连另一台机器。SSH（密码 / 私钥、TOFU）或 DSH Remote，手机版也能反向接管这台 Mac。'
  }
] as const;

export const PROOF = [
  {
    no: '01',
    label: 'RECORDING',
    meta: '10.0 S · NO CUTS',
    src: '/images/demo.gif',
    alt: 'DSH Go Mac 真实录屏',
    caption: '思考、建目录、写文件、运行。一个真实的工具调用回合。'
  },
  {
    no: '02',
    label: 'RUN',
    meta: '0:41 · 6 STEPS · 1 FILE',
    src: '/images/app/app-dark.jpg',
    alt: '一次真实运行的对话与右侧运行详情',
    caption: '右侧不是装饰：用时、步骤、改动文件，全部来自这次运行。'
  },
  {
    no: '03',
    label: 'SURFACE',
    meta: 'NEW CHAT · THIS MAC',
    src: '/images/app/new-chat.jpg',
    alt: 'DSH Go Mac 新对话界面',
    caption: '它先是一个安静的 macOS 客户端，然后才是运行详情。'
  }
] as const;

export const NATIVE = [
  {
    no: '01',
    title: '通知里就能审批',
    body: '一轮结束、等待确认，系统通知上直接「允许 / 拒绝」，点一下回到对话。不是网页里的按钮。',
    kind: 'a'
  },
  {
    no: '02',
    title: '文件、PDF、语音、桌宠',
    body: '打开、另存、PDFKit 预览、SFSpeechRecognizer 语音、无边框桌宠浮窗，全走 macOS API。',
    kind: 'b'
  },
  {
    no: '03',
    title: '动效是功能',
    body: '思考胶囊呼吸、工具行滑入、折叠连续展开。长任务里，扫一眼就知道状态。',
    kind: 'c'
  }
] as const;
