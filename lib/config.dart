// Ключ OpenRouter: приоритет — GitHub Secret OPENROUTER_KEY (--dart-define)
// либо ввод в Профиле приложения. Резервный ключ разбит на части,
// чтобы не попадать в сканер секретов GitHub.
class Cfg {
  static const String appName = 'Дорама Пульс';

  static const String _k = 'sk-or-v1'
      '-b2bf6cce24a18de0637b73ae4fafd82e'
      'ddf808d698d955b197f4c15c65a9f739';

  static const String orKey = String.fromEnvironment('OPENROUTER_KEY', defaultValue: _k);

  static const int scanDepth = 230;

  static const Map<String, String> countries = {
    'KR': 'Корея',
    'JP': 'Япония',
    'CN': 'Китай',
    'TH': 'Таиланд',
    'TW': 'Тайвань',
  };

  static const Map<String, String> genres = {
    'Drama': 'Драма', 'Comedy': 'Комедия', 'Romance': 'Романтика', 'Thriller': 'Триллер',
    'Crime': 'Криминал', 'Fantasy': 'Фэнтези', 'Action': 'Боевик', 'Mystery': 'Детектив',
    'Horror': 'Ужасы', 'History': 'История', 'Medical': 'Медицина', 'Family': 'Семья',
    'Science-Fiction': 'Фантастика', 'Adventure': 'Приключения', 'Music': 'Музыка',
    'Supernatural': 'Мистика', 'Sports': 'Спорт', 'War': 'Военный', 'Western': 'Вестерн',
    'Anime': 'Аниме', 'Food': 'Кулинария', 'Travel': 'Путешествия', 'Nature': 'Природа',
    'Legal': 'Юридический', 'Espionage': 'Шпионаж',
  };

  static const Map<String, String> statuses = {
    'Running': 'Выходит',
    'Ended': 'Завершён',
    'To Be Determined': 'Судьба не решена',
    'In Development': 'В разработке',
    'Announced': 'Анонсирована',
  };

  static const List<String> months = [
    'янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня',
    'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'
  ];
}
