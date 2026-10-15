class Cfg {
  static const String appName = 'Дорама Пульс';
  static const int scanDepth = 60;
  static const int minYear = 2022;

  static const Map<String, String> countries = {'KR': 'Корея'};

  static const Map<String, String> genres = {
    'Drama': 'Драма', 'Comedy': 'Комедия', 'Romance': 'Романтика',
    'Thriller': 'Триллер', 'Crime': 'Криминал', 'Fantasy': 'Фэнтези',
    'Action': 'Боевик', 'Mystery': 'Детектив', 'Horror': 'Ужасы',
    'History': 'История', 'Medical': 'Медицина', 'Family': 'Семья',
    'Science-Fiction': 'Фантастика', 'Adventure': 'Приключения',
    'Music': 'Музыка', 'Supernatural': 'Мистика', 'Sports': 'Спорт',
    'War': 'Военный', 'Legal': 'Юридический', 'Espionage': 'Шпионаж',
  };

  static const Map<String, String> statuses = {
    'Running': 'Выходит', 'Ended': 'Завершён',
    'To Be Determined': 'Судьба не решена',
    'In Development': 'В разработке', 'Announced': 'Анонсирована',
  };

  static const List<String> months = [
    'янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня',
    'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'
  ];
}
