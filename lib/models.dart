class Drama {
  final int id;
  String en;
  int? year;
  String date;
  String poster;
  double? rating;
  List<String> genres;
  String imdb;
  String country;
  String status;
  String network;
  int seen;
  String titleSource;
  String titleRu;

  Drama({
    required this.id, required this.en,
    this.year, this.date = '', this.poster = '', this.rating,
    this.genres = const <String>[], this.imdb = '', this.country = '',
    this.status = '', this.network = '', this.seen = 0,
    this.titleSource = '', this.titleRu = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'en': en, 'y': year, 'd': date, 'p': poster, 'r': rating,
    'g': genres, 'im': imdb, 'c': country, 's': status, 'n': network,
    'f': seen, 'ts': titleSource, 'tr': titleRu,
  };

  factory Drama.fromJson(Map<String, dynamic> j) => Drama(
    id: j['id'] as int,
    en: (j['en'] ?? '').toString(),
    year: j['y'] as int?,
    date: (j['d'] ?? '').toString(),
    poster: (j['p'] ?? '').toString(),
    rating: (j['r'] as num?)?.toDouble(),
    genres: ((j['g'] ?? <dynamic>[]) as List).map((e) => e.toString()).toList(),
    imdb: (j['im'] ?? '').toString(),
    country: (j['c'] ?? '').toString(),
    status: (j['s'] ?? '').toString(),
    network: (j['n'] ?? '').toString(),
    seen: (j['f'] ?? 0) as int,
    titleSource: (j['ts'] ?? '').toString(),
    titleRu: (j['tr'] ?? '').toString(),
  );
}

class LiveItem {
  final Drama drama; final String time; final int? number;
  LiveItem({required this.drama, required this.time, this.number});
}

class SumRes {
  final String text; final String src;
  SumRes(this.text, this.src);
}

class Ep {
  final int season; final int number; final String name; final String airdate; final String time;
  const Ep(this.season, this.number, this.name, this.airdate, this.time);
}

class Actor {
  final int id; final String name; final String role; final String photo;
  const Actor(this.id, this.name, this.role, this.photo);
}

class AwardItem {
  final String year;
  final String award;
  final String why;
  const AwardItem(this.year, this.award, this.why);

  Map<String, dynamic> toJson() => {'y': year, 'a': award, 'w': why};

  factory AwardItem.fromJson(Map<String, dynamic> j) => AwardItem(
    (j['y'] ?? '').toString(),
    (j['a'] ?? '').toString(),
    (j['w'] ?? '').toString(),
  );
}

class RuHit {
  final String ru; final String en; final int? year; final String imdb; final String src;
  const RuHit(this.ru, this.en, this.year, this.imdb, this.src);
}

class NextEpInfo {
  final int number;
  final int season;
  final String airdate;
  final String time;
  final DateTime target;
  final bool isPremiere;
  const NextEpInfo({
    required this.number,
    required this.season,
    required this.airdate,
    required this.time,
    required this.target,
    this.isPremiere = false,
  });
}

class RadarEvent {
  final Drama drama;
  final String actorName;
  final String actorRu;
  final String kind; // 'ep', 'announce', 'watch_ep'
  final String title;
  final String subtitle;
  final String date;
  const RadarEvent({
    required this.drama,
    required this.actorName,
    required this.actorRu,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.date,
  });
}
class NotifLogItem {
  final String id;
  final String title;
  final String body;
  final int ts;
  final String kind;

  const NotifLogItem({
    required this.id,
    required this.title,
    required this.body,
    required this.ts,
    this.kind = 'update',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    't': title,
    'b': body,
    'ts': ts,
    'k': kind,
  };

  factory NotifLogItem.fromJson(Map<String, dynamic> j) => NotifLogItem(
    id: (j['id'] ?? '').toString(),
    title: (j['t'] ?? '').toString(),
    body: (j['b'] ?? '').toString(),
    ts: (j['ts'] as num?)?.toInt() ?? 0,
    kind: (j['k'] ?? 'update').toString(),
  );
}
