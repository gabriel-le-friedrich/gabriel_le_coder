// ══════════════════════════════════════════════════════════════════════
// The legacy web app supports exactly two languages (English/Filipino, a
// hand-rolled T.en/T.fil dictionary + a single toggle — see index.html's
// toggleLang()), not a picker over many locales. This enum mirrors that
// shape faithfully rather than inventing a bigger locale list the source
// app never had.
// ══════════════════════════════════════════════════════════════════════

enum AppLanguage {
  en,
  fil;

  String get code => this == AppLanguage.en ? 'en' : 'fil';

  String get label => this == AppLanguage.en ? 'English' : 'Filipino';

  static AppLanguage fromCode(String? code) =>
      code == 'fil' ? AppLanguage.fil : AppLanguage.en;
}
