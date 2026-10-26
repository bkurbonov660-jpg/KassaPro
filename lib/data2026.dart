import 'models.dart';

class RichDramaMeta {
  final String ruTitle;
  final List<String> genres;
  final double? rating;
  final int episodes;
  final String poster;
  final String summary;
  const RichDramaMeta({
    required this.ruTitle,
    this.genres = const <String>[],
    this.rating,
    this.episodes = 0,
    this.poster = '',
    this.summary = '',
  });
}

// База полностью очищена для ручного заполнения через dorama_pulse_db.json
const Map<String, String> kActorsRu2026 = {};
const Map<String, String> kActorPhotos = {};
const Map<String, RichDramaMeta> kRich2026 = {};
const Map<String, List<Actor>> kCast2026 = {};
const Map<String, List<String>> kActorDramas = {};
const Map<String, List<AwardItem>> kActorAwards = {};
const List<String> k2026 = [];

// Популярные студии озвучки и перевода для быстрого выбора в карточке дорамы.
const List<String> kDubStudios = [
  'SoftBox',
  'DubLik TV',
  'FSG Мания',
  'Принц Лимон и Аконя',
  'STEPonee',
  'Храм Дорам',
  'АниМаунт',
  'HighHopes',
  'FSG Кардинал',
  'Субтитры',
  'Официальная',
];

// Список популярных актёров очищен — берётся из вашего dorama_pulse_db.json
const List<Actor> kPopularCrushes = [];
