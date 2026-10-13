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

  Drama({
    required this.id,
    required this.en,
    this.year,
    this.date = '',
    this.poster = '',
    this.rating,
    this.genres = const <String>[],
    this.imdb = '',
    this.country = '',
    this.status = '',
    this.network = '',
    this.seen = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'en': en, 'y': year, 'd': date, 'p': poster, 'r': rating,
        'g': genres, 'im': imdb, 'c': country, 's': status, 'n': network, 'f': seen,
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
      );
}

class LiveItem {
  final Drama drama;
  final String time;
  final int? number;
  LiveItem({required this.drama, required this.time, this.number});
}

class SumRes {
  final String text;
  final String src;
  SumRes(this.text, this.src);
}
