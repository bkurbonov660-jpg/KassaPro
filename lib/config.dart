class Cfg {
  static const String appName = 'Дорама Пульс';
  static const int scanDepth = 160;
  static const String contactEmail = 'obanstudio.0@gmail.com';
  static const String tgUrl = 'https://t.me/PULSEDORAM';
  static const int minYear = 2022;
  // Ветка data в этом же репозитории: туда сервер раз в 2 дня кладёт свежую переведённую базу.
  static const String dataBase = 'https://raw.githubusercontent.com/bkurbonov660-jpg/KassaPro/data';

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
