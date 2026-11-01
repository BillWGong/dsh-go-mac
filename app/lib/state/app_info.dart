import '../l10n/l10n.dart';

/// Build-time app metadata.
///
/// There is no package_info plugin in the dependency set, so the version is a
/// constant kept in sync with `pubspec.yaml` (`version: 1.0.2+1`). Release builds can
/// override it: `flutter build apk --dart-define=DSH_APP_VERSION=1.2.0+7`.
abstract final class AppInfo {
  static const version = String.fromEnvironment('DSH_APP_VERSION', defaultValue: '1.0.16+1');

  /// "1.0.0 (1)" for display.
  static String get displayVersion {
    final parts = version.split('+');
    return parts.length == 2 ? '${parts[0]} (${parts[1]})' : version;
  }

  /// The app's name as the system shows it: window, notifications, system
  /// settings, the licence page.
  static const name = 'DSH Go Mac';

  /// The in-app wordmark: the drawer's lockup, the welcome page and the brand mark's
  /// spoken label.
  static const wordmark = 'DSH';

  /// DSH Go Mac 的作者与仓库。
  static const author = 'BillWGong';
  static const repoUrl = 'https://github.com/BillWGong/dsh-go-mac';

  /// 上游 DSH Go（Android）的作者与仓库：支持原作者用。
  static const upstreamAuthor = 'ccch1mneyyy';
  static const upstreamUrl = 'https://github.com/ccch1mneyyy/dsh-go';

  /// Required wording: the app is built on DSH but is not an official DeepSeek product.
  /// Shown where legal text lives (the licence page).
  static String get disclaimer => appL10n.stateAppDisclaimer;

  /// The line under the brand mark (welcome page, 关于 dsh-go).
  static String get slogan => appL10n.appSlogan;

  static const deepseekPlatform = 'https://platform.deepseek.com/api_keys';
  static const remoteConsole = 'https://dsh.r2049.cn/app';

  /// DSH Remote's upstream, credited under the DSH Remote card as its GitHub
  /// handle and name.
  static const remoteProject = 'liguobao/ds-harness-remote';
  static const remoteProjectUrl = 'https://github.com/$remoteProject';
}
