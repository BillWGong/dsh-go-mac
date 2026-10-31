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
  String phoneControlRemoteHint(String host) => '「$host」上的 DSH 操作不了这台 Mac，切回「本机」后可用';

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
  String phoneControlRemoteHint(String host) => 'DSH on “$host” can’t control this Mac. Switch to “This Mac” to use it.';

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
