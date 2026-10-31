// macOS 文案覆盖：把 Android 版里「这台手机」「手机上的 DSH」「Android Keystore」
// 这类**指代当前设备**的说法换掉；Android 专属功能名（手机操控、手机文件、Shizuku…）
// 保持原样，等对应功能移植后再改。
//
// 做法是继承 gen-l10n 生成的 L10nZh / L10nEn 覆盖少数 getter，而不是改 ARB：
//   - 不动 740 个界面文件里的任何调用点；
//   - 不生成第二套 l10n，Android 构建不受影响；
//   - 以后接 Mac 操控时，把 phoneControl* 也在这里覆盖即可。

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../l10n/gen/app_localizations_en.dart';
import '../l10n/gen/app_localizations_zh.dart';

/// macOS 文案是否生效。`flutter test` 里固定为 false：既有测试和 golden 都是按
/// 手机文案写的，跑在 Mac 上也不该变。
bool get macTextActive =>
    !kIsWeb && Platform.isMacOS && Platform.environment['FLUTTER_TEST'] != 'true';

/// 中文 macOS 文案。
class MacL10nZh extends L10nZh {
  MacL10nZh([super.locale = 'zh']);

  @override
  String get hubAbout => '关于 DSH Go Mac';

  @override
  String get starSettingsTitle => '给 DSH Go Mac 点个 star';

  @override
  String get hubSettingsStorageTitle => '让 AI 访问这台 Mac 上的文件？';

  @override
  String get hubSettingsWebPhoneLayout => '网页版竖屏布局';

  @override
  String get hubSettingsWebPhoneLayoutHint => '为窄屏重排网页版';

  @override
  String get hubInterfacePhoneLayout => '竖屏版式';

  @override
  String get hubSettingsPhoneFiles => '访问本机文件';

  @override
  String get hubSettingsPhoneFilesHint => 'AI 可读写这台 Mac 的存储';

  @override
  String get hubSettingsStorageBody => 'AI 能读取和修改这台 Mac 上的文件，引擎会重启一次。';

  @override
  String get accessFeatureFiles => '读写这台 Mac 上的文件';

  @override
  String get accessFilesRiskBody => 'AI 能读取和修改这台 Mac 上的文件。';

  @override
  String get accessA11yWhy => 'Mac 操控靠它看屏幕、点按';

  @override
  String get a11yRestoreNotice => '开启后，在系统设置里关掉辅助功能会被自动打开；要关闭 Mac 操控，请在 DSH Go 里关。';

  @override
  String get remoteDirectoryPhoneStorage => '本机存储';

  @override
  String get remoteDirectoryDownloadsPath => '下载';

  @override
  String get remoteDirectoryDocumentsPath => '文稿';

  @override
  String remoteDirectoryPhonePath(String path) => path;

  @override
  String viewSharePhoneInstall(String value) => '在 Mac 上安装：$value';

  @override
  String get pluginsPermissionLocalThirdParty =>
      '插件以 DSH 的权限运行：能读写文件、执行命令、读取 API Key 和已授权的本机存储，不受工作区沙箱限制。由第三方提供，DSH 官方未审核。';

  @override
  String get pluginsPermissionLocalTrusted =>
      '插件以 DSH 的权限运行：能读写文件、执行命令、读取 API Key 和已授权的本机存储，不受工作区沙箱限制。只装你信任的插件。';

  @override
  String get plugslotsVoiceWhen => '朗读时你一开口就停。声音只在这台 Mac 上判断，不保存、不上传';

  @override
  String phoneControlRemoteHint(String host) => '「$host」上的 DSH 操作不了这台 Mac，切回「本机」后可用';

  @override
  String get phoneAppRulesSkipStepsBody =>
      '微信这类 App 有风控，曾有自动化操作后账号被强制下线。改成照常后，只有发消息这类操作还会先问你。';

  @override
  String get phoneDirectHint => '实验功能，默认关闭，下次启动生效。部分系统会拦截直接启动，届时自动改用兼容启动，数据不受影响。';

  @override
  String get phoneDirectFailedHint => '这台 Mac 上直接启动没有成功，已改用兼容启动。停止引擎后打开可再试一次。';

  @override
  String get updateIncompatible => '和这台 Mac 不兼容';

  @override
  String get updateIncompatibleMessage => '安装包要求的系统版本或处理器架构和这台 Mac 不符。';

  @override
  String get botsMobileUnsupportedTitle => 'DS Bot 暂不支持桌面端';

  @override
  String get botsMobileApiMissing => '桌面端暂不支持，可先在网页版中使用';

  @override
  String get searchKwPhone => '无障碍,操作 Mac,自动点击,代操作,点按';

  @override
  String get searchKwPhoneFiles => '存储,文件,相册,下载,本机存储';

  @override
  String get searchKwWebPhoneLayout => '网页版竖屏布局,布局';

  @override
  String get searchKwPhoneConfirmEntry => '确认方式,Mac 操控,免确认';

  @override
  String get askAiQuestionPhoneControl => 'Mac 操控是怎么工作的？有什么风险？';

  @override
  String get askAiQuestionPhoneAlways => 'Mac 操控选「始终免确认」会怎样？和「每次都询问」比风险在哪？';

  @override
  String get askAiQuestionAppRules => 'Mac 操控的应用名单有什么用？放开银行、支付类 App 有什么风险？';

  @override
  String get askAiQuestionPhoneFiles => '「访问本机文件」打开后，AI 能读写哪些文件？怎么关掉？';

  @override
  String get phoneBackgroundGuideBody =>
      '需要你确认时，会显示 DSH Go 卡片。卡片不可用时会尝试通知或回到 App。请在系统设置中允许 Mac 操控通知和弹出提醒。';

  @override
  String get phoneBackgroundNotificationBlocked => '请允许 Mac 操控通知的弹出提醒';

  @override
  String get localEnvInstallMessage => '在这台 Mac 上运行 DSH';

  @override
  String get chatVoiceUnavailable => '这台 Mac 没有可用的语音识别';

  @override
  String get chatOpenInPhoneApp => '用 Mac 上的应用打开';

  @override
  String get chatAlreadyInDownloads => '已在「下载」里';

  @override
  String get stateCheckPhoneNetwork => '检查这台 Mac 的网络后重试';

  @override
  String get stateFileNoApp => '这台 Mac 上没有能打开这类文件的应用';

  @override
  String get statePluginPhonePnpmMissing => '这台 Mac 缺少 pnpm';

  @override
  String get usageStatsFooter => '只含使用次数、版本和机型，不含对话、文件和账号。';

  @override
  String get viewArtifactPhoneOpen => '用 Mac 上的应用打开';

  @override
  String get voiceModeSystemHint => '使用系统设置中的语音识别服务';

  @override
  String get voiceModelFailCertificate => '安全连接失败，请检查这台 Mac 的时间';

  @override
  String get voiceModelFooter => '下载后在这台 Mac 上识别中文、英文、粤语、日语和韩语，录音不出这台 Mac。';

  @override
  String get remoteHostsIntro => '在这台 Mac 上接着用电脑或服务器上的 DSH';

  @override
  String get remoteThisPhoneDsh => '这台 Mac 上的 DSH';

  @override
  String get remoteKeyStorageHelp => '只保存在这台 Mac 上，由钥匙串加密。支持 Ed25519、RSA、ECDSA';

  @override
  String get remotePasswordStorageHelp => '只保存在这台 Mac 上，由钥匙串加密';

  @override
  String get remoteRelaySignOutBody => '这台 Mac 会从账号中移除。主机上的 DSH 和对话不受影响，随时可以重新登录。';

  @override
  String get remoteDeleteHostBody => '这台主机的设置和保存在这台 Mac 上的密码、私钥都会删除。主机上的 DSH 和对话不受影响。';

  @override
  String get accessFeaturePhone => 'Mac 操控';

  @override
  String get accessPopupWhy => 'Mac 操控做完能回到 DSH Go';

  @override
  String get catalogPhoneControl => 'Mac 操控';

  @override
  String get hubSettingsPhoneControl => 'Mac 操控';

  @override
  String get hubPermissionPhone => 'Mac 操控';

  @override
  String get hubPermissionPhoneConfirm => 'Mac 操控确认';

  @override
  String get phoneControlTitle => 'Mac 操控';

  @override
  String get phoneControlReady => '可以操作这台 Mac';

  @override
  String get phoneControlWorking => '正在操作这台 Mac';

  @override
  String get phoneControlModuleNotReady => '这个版本里，Mac 操控模块还没有就绪';

  @override
  String get statePhoneNotReady => 'Mac 操控模块未就绪';

  @override
  String get phoneDisclosureTitle => '开启 Mac 操控前';

  @override
  String get phoneDisclosureStopBody => '操作时屏幕上有悬浮条，可以暂停、停止或插话。先在系统设置里允许 DSH Go 使用辅助功能。';

  @override
  String get phoneActionLogEmptyHint => 'DSH 在这台 Mac 上的每一步都会记在这里';

  @override
  String get phoneModeAutoUnlockNote => '如需让 AI 操作系统设置、密码等，可在 设置 › Mac 操控 中开启。';

  @override
  String get searchNeedsPhoneControl => '开启 Mac 操控后可用';
}

/// English macOS wording.
class MacL10nEn extends L10nEn {
  MacL10nEn([super.locale = 'en']);

  @override
  String get hubAbout => 'About DSH Go Mac';

  @override
  String get starSettingsTitle => 'Star DSH Go Mac';

  @override
  String get hubSettingsStorageTitle => 'Let AI access files on this Mac?';

  @override
  String get hubSettingsWebPhoneLayout => 'Portrait layout for the web view';

  @override
  String get hubSettingsWebPhoneLayoutHint => 'Rearrange the web view for narrow screens';

  @override
  String get hubInterfacePhoneLayout => 'Portrait layout';

  @override
  String get hubSettingsPhoneFiles => 'Access this Mac’s files';

  @override
  String get hubSettingsPhoneFilesHint => 'AI can read and write this Mac’s storage';

  @override
  String get hubSettingsStorageBody => 'AI can read and change files on this Mac; the engine restarts once.';

  @override
  String get accessFeatureFiles => 'Read and write files on this Mac';

  @override
  String get accessFilesRiskBody => 'AI can read and change files on this Mac.';

  @override
  String get accessA11yWhy => 'Mac control uses it to see the screen and click';

  @override
  String get a11yRestoreNotice =>
      'Once on, turning accessibility off in System Settings is switched back on. To stop Mac control, turn it off in DSH Go.';

  @override
  String get remoteDirectoryPhoneStorage => 'This Mac';

  @override
  String get remoteDirectoryDownloadsPath => 'Downloads';

  @override
  String get remoteDirectoryDocumentsPath => 'Documents';

  @override
  String remoteDirectoryPhonePath(String path) => path;

  @override
  String viewSharePhoneInstall(String value) => 'Install on your Mac: $value';

  @override
  String get pluginsPermissionLocalThirdParty =>
      'Plugins run with DSH’s permissions: read and write files, run commands, read API keys and authorised local storage, outside the workspace sandbox. Third-party, not reviewed by DSH.';

  @override
  String get pluginsPermissionLocalTrusted =>
      'Plugins run with DSH’s permissions: read and write files, run commands, read API keys and authorised local storage, outside the workspace sandbox. Only install ones you trust.';

  @override
  String get plugslotsVoiceWhen => 'Reading stops when you speak. Audio is judged only on this Mac; never saved or uploaded';

  @override
  String phoneControlRemoteHint(String host) => 'DSH on “$host” cannot control this Mac; switch back to This Mac';

  @override
  String get phoneAppRulesSkipStepsBody =>
      'Apps like WeChat police automation; accounts have been forced offline after assisted use. On Normal, only actions like sending a message ask first.';

  @override
  String get phoneDirectHint =>
      'Experimental, off by default, applies next launch. Some systems block a direct start; it falls back to compatible start with no data loss.';

  @override
  String get phoneDirectFailedHint =>
      'A direct start did not work on this Mac, so the compatible start was used. Stop the engine and open it again to retry.';

  @override
  String get updateIncompatible => 'Not compatible with this Mac';

  @override
  String get updateIncompatibleMessage => 'The package needs a different macOS version or CPU architecture.';

  @override
  String get botsMobileUnsupportedTitle => 'DS Bot is not supported on desktop yet';

  @override
  String get botsMobileApiMissing => 'Not supported on desktop yet; use it on the web for now';

  @override
  String get searchKwPhone => 'accessibility, Mac control, click, automation, tap';

  @override
  String get searchKwPhoneFiles => 'storage, files, photos, downloads, local storage';

  @override
  String get searchKwWebPhoneLayout => 'web portrait layout, layout';

  @override
  String get searchKwPhoneConfirmEntry => 'confirmation, Mac control, no confirmation';

  @override
  String get askAiQuestionPhoneControl => 'How does Mac control work, and what are the risks?';

  @override
  String get askAiQuestionPhoneAlways => 'What happens with “always allow” in Mac control, and how does it compare with asking every time?';

  @override
  String get askAiQuestionAppRules => 'What is the app list in Mac control for, and what are the risks of allowing banking and payment apps?';

  @override
  String get askAiQuestionPhoneFiles => 'With “access local files” on, which files can the AI read and write? How do I turn it off?';

  @override
  String get phoneBackgroundGuideBody =>
      'When you need to confirm, a DSH Go card appears. If cards are unavailable it tries a notification or returns to the app. Allow Mac control notifications and banners in System Settings.';

  @override
  String get phoneBackgroundNotificationBlocked => 'Allow Mac control notification banners';

  @override
  String get localEnvInstallMessage => 'Run DSH right on this Mac';

  @override
  String get chatVoiceUnavailable => 'Speech recognition isn’t available on this Mac';

  @override
  String get chatOpenInPhoneApp => 'Open in an app on this Mac';

  @override
  String get chatAlreadyInDownloads => 'Already in Downloads';

  @override
  String get stateCheckPhoneNetwork => 'Check this Mac’s network and try again';

  @override
  String get stateFileNoApp => 'No app on this Mac can open this file type';

  @override
  String get statePluginPhonePnpmMissing => 'pnpm is missing on this Mac';

  @override
  String get usageStatsFooter => 'Only usage counts, versions and the Mac model. Never chats, files or accounts.';

  @override
  String get viewArtifactPhoneOpen => 'Open in an app on this Mac';

  @override
  String get voiceModeSystemHint => 'Use the recognition service selected in System Settings';

  @override
  String get voiceModelFailCertificate => 'Secure connection failed; check this Mac’s date';

  @override
  String get voiceModelFooter =>
      'Once downloaded, Chinese, English, Cantonese, Japanese and Korean are recognized on this Mac; recordings stay here.';

  @override
  String get remoteHostsIntro => 'Keep using DSH from your computer or server on this Mac';

  @override
  String get remoteThisPhoneDsh => 'DSH on this Mac';

  @override
  String get remoteKeyStorageHelp => 'Saved only on this Mac, encrypted by the Keychain. Supports Ed25519, RSA and ECDSA.';

  @override
  String get remotePasswordStorageHelp => 'Saved only on this Mac, encrypted by the Keychain';

  @override
  String get remoteRelaySignOutBody =>
      'This Mac will be removed from your account. DSH and chats on the host stay. You can sign in again anytime.';

  @override
  String get remoteDeleteHostBody =>
      'This host’s settings and the password and private key saved on this Mac will be deleted. DSH and chats on the host stay.';

  @override
  String get accessFeaturePhone => 'Mac control';

  @override
  String get accessPopupWhy => 'Brings you back to DSH Go when Mac control is done';

  @override
  String get catalogPhoneControl => 'Mac control';

  @override
  String get hubSettingsPhoneControl => 'Mac control';

  @override
  String get hubPermissionPhone => 'Mac control';

  @override
  String get hubPermissionPhoneConfirm => 'Mac control confirmation';

  @override
  String get phoneControlTitle => 'Mac control';

  @override
  String get phoneControlReady => 'Ready to control this Mac';

  @override
  String get phoneControlWorking => 'Operating this Mac';

  @override
  String get phoneControlModuleNotReady => 'Mac control isn’t ready in this version';

  @override
  String get statePhoneNotReady => 'Mac control isn’t ready';

  @override
  String get phoneDisclosureTitle => 'Before turning on Mac control';

  @override
  String get phoneDisclosureStopBody =>
      'A floating bar lets you pause, stop or steer. Allow DSH Go in Accessibility first.';

  @override
  String get phoneActionLogEmptyHint => 'Every step DSH takes on this Mac appears here';

  @override
  String get phoneModeAutoUnlockNote =>
      'To let AI handle system settings, passwords and the like, turn it on in Settings › Mac control.';

  @override
  String get searchNeedsPhoneControl => 'Available once Mac control is on';
}
