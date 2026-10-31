// The one import for UI text: `import '../../l10n/l10n.dart';`
//
//  - In widgets: `context.l10n.chatComposerHint`.
//  - Without a BuildContext (state, services, error mapping): `appL10n.xxx`,
//    which always follows the language the app is showing.
//
// Strings live in lib/l10n/parts/<area>_{zh,en}.arb; tool/l10n_merge.py
// merges them and regenerates lib/l10n/gen/.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../macos/mac_localizations.dart';
import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// The language the app shows: what [AppLocale.resolve] picked from the
/// user's choice and the system languages.
abstract final class AppLocale {
  static const zhCN = Locale('zh', 'CN');
  static const en = Locale('en');

  /// Locales MaterialApp offers. zh_CN (not bare zh) keeps CJK glyphs
  /// Chinese on non-Chinese systems (typography.dart「汉字字形」).
  static const supported = [zhCN, en];

  static Locale _locale = zhCN;
  static L10n _l10n = l10nFor(zhCN);

  /// 生成的那套文案，macOS 上换成 Mac 措辞（见 lib/macos/mac_localizations.dart）。
  static L10n l10nFor(Locale locale) {
    if (macTextActive) {
      return locale.languageCode == 'en' ? MacL10nEn() : MacL10nZh();
    }
    return lookupL10n(locale);
  }

  /// The locale in use (zh_CN until the app resolves one; tests keep it).
  static Locale get current => _locale;

  static bool get isEnglish => _locale.languageCode == 'en';

  static L10n get l10n => _l10n;

  /// Switches [appL10n] to [locale] (zh_CN or en).
  static void use(Locale locale) {
    final next = locale.languageCode == 'en' ? en : zhCN;
    if (next == _locale) return;
    _locale = next;
    _l10n = l10nFor(next);
  }

  /// Chinese for any Chinese system language, English for everything else.
  static Locale resolve(Locale? chosen, List<Locale>? system) {
    if (chosen != null) return chosen.languageCode == 'en' ? en : zhCN;
    for (final l in system ?? const <Locale>[]) {
      if (l.languageCode == 'zh') return zhCN;
      if (l.languageCode == 'en') return en;
    }
    return (system == null || system.isEmpty) ? zhCN : en;
  }
}

/// `Localizations` 用的 delegate：和生成的 [L10n.delegate] 一样，只是 macOS 上返回
/// Mac 措辞。[L10n.delegate] 仍是默认，测试和 Android 构建不受影响。
class AppL10nDelegate extends LocalizationsDelegate<L10n> {
  const AppL10nDelegate();

  @override
  bool isSupported(Locale locale) => L10n.delegate.isSupported(locale);

  @override
  Future<L10n> load(Locale locale) => SynchronousFuture<L10n>(AppLocale.l10nFor(locale));

  @override
  bool shouldReload(AppL10nDelegate old) => false;
}

/// UI text for code without a BuildContext. Follows the app language.
L10n get appL10n => AppLocale.l10n;

extension L10nContext on BuildContext {
  /// UI text in the app language. Falls back to [appL10n] where the tree has
  /// no L10n delegate (bare MaterialApps in tests).
  L10n get l10n => Localizations.of<L10n>(this, L10n) ?? AppLocale.l10n;
}

extension L10nFormat on L10n {
  /// 「3月5日」/「Mar 5」.
  String monthDay(DateTime d) => commonMonthDay('${d.month}', d.day);
}
