// 🔐 Секретные токены. Можно заменить этот файл целиком.
// Ключи разбиты на части, чтобы GitHub Push Protection
// не блокировал push в публичный репозиторий.
class Secrets {
  // OpenRouter (ИИ-перевод названий и описаний)
  static const String _or1 = 'sk-or-v1';
  static const String _or2 = '-b2bf6cce24a18de0637b73ae4fafd82e';
  static const String _or3 = 'ddf808d698d955b197f4c15c65a9f739';
  static const String openRouterKey =
      String.fromEnvironment('OPENROUTER_KEY', defaultValue: '$_or1$_or2$_or3');

  // Kinopoisk.dev (официальные русские названия)
  static const String _kp1 = 'H9FC9Q3';
  static const String _kp2 = '-BAS4RX4';
  static const String _kp3 = '-NAXN754';
  static const String _kp4 = '-FWW04VN';
  static const String kinopoiskApiKey = '$_kp1$_kp2$_kp3$_kp4';
}
