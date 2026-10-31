import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/macos/mac_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('指代当前设备的说法换成 Mac', () {
    final zh = MacL10nZh();
    expect(zh.localEnvInstallMessage, '在这台 Mac 上运行 DSH');
    expect(zh.remoteThisPhoneDsh, '这台 Mac 上的 DSH');
    expect(zh.chatOpenInPhoneApp, '用 Mac 上的应用打开');
    expect(zh.remoteKeyStorageHelp, contains('钥匙串'));
    expect(zh.remoteKeyStorageHelp, isNot(contains('Android')));

    final en = MacL10nEn();
    expect(en.localEnvInstallMessage, 'Run DSH right on this Mac');
    expect(en.remoteThisPhoneDsh, 'DSH on this Mac');
    expect(en.remoteKeyStorageHelp, contains('Keychain'));
  });

  test('手机操控改名 Mac 操控，带占位符的句子也换掉', () {
    expect(MacL10nZh().phoneControlTitle, 'Mac 操控');
    expect(MacL10nEn().phoneControlTitle, 'Mac control');
    expect(MacL10nZh().phoneControlRemoteHint('工作机'), contains('这台 Mac'));
    expect(MacL10nEn().phoneControlRemoteHint('work'), contains('this Mac'));
  });

  test('测试环境不走 Mac 文案（既有 golden / 断言按手机写）', () {
    expect(macTextActive, isFalse);
    expect(AppLocale.l10n.localEnvInstallMessage, '在这台手机上运行 DSH');
  });
}
