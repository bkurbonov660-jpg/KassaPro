// Сборка каталога из единого ручного файла assets/dorama_pulse_db.json (без внешних API и интернета).
import 'dart:convert';
import 'dart:io';

void main() {
  final dbFile = File('assets/dorama_pulse_db.json');
  Map<String, dynamic> db = <String, dynamic>{};
  if (dbFile.existsSync()) {
    try {
      db = Map<String, dynamic>.from(jsonDecode(dbFile.readAsStringSync()) as Map);
    } catch (e) {
      stdout.writeln('Ошибка чтения assets/dorama_pulse_db.json: $e');
    }
  }
  final rawDramas = (db['dramas'] is List) ? (db['dramas'] as List) : <dynamic>[];
  final rawActors = (db['actors'] is Map) ? Map<String, dynamic>.from(db['actors'] as Map) : <String, dynamic>{};

  final outDramas = <Map<String, dynamic>>[];
  final trOut = <String, String>{};
  final trSrcOut = <String, String>{};
  final sumOut = <String, String>{};
  var nextId = 1;

  for (final item in rawDramas) {
    if (item is! Map) continue;
    final id = item['id'] is int ? item['id'] as int : nextId++;
    if (id >= nextId) nextId = id + 1;
    final en = (item['en'] ?? item['title'] ?? item['ru'] ?? '').toString().trim();
    final ru = (item['ru'] ?? item['titleRu'] ?? '').toString().trim();
    if (en.isEmpty && ru.isEmpty) continue;
    final effEn = en.isNotEmpty ? en : ru;
    final date = (item['date'] ?? '').toString().trim();
    final year = item['year'] is int ? item['year'] as int : (date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null);
    outDramas.add({
      'id': id,
      'en': effEn,
      'y': year,
      'd': date,
      'p': (item['poster'] ?? '').toString().trim(),
      'r': (item['rating'] is num) ? (item['rating'] as num).toDouble() : null,
      'g': (item['genres'] is List) ? (item['genres'] as List).map((e) => '$e').toList() : <String>[],
      'im': (item['imdb'] ?? '').toString().trim(),
      'c': 'KR',
      's': (item['status'] ?? 'Running').toString().trim(),
      'n': (item['network'] ?? '').toString().trim(),
      'f': 0,
      'ts': 'fix',
      'tr': ru,
    });
    if (ru.isNotEmpty) {
      trOut['$id'] = ru;
      trSrcOut['$id'] = 'fix';
    }
    final sum = (item['summary'] ?? '').toString().trim();
    if (sum.isNotEmpty) {
      sumOut['$id'] = sum;
    }
  }

  final out = <String, dynamic>{
    'v': 1,
    'gen': 2,
    'built': DateTime.now().toUtc().toIso8601String().substring(0, 16),
    'scanMax': 0,
    'fullAt': 0,
    'dramas': outDramas,
    'tr': trOut,
    'trSrc': trSrcOut,
    'tried': <String, int>{},
    'sum': sumOut,
    'actorRu': <String, String>{},
    'actorPhotos': <String, String>{},
    'dramasByActor': <String, List<String>>{},
    'awards': <String, List<Map<String, dynamic>>>{},
  };
  File('assets/seed_catalog.json').writeAsStringSync(jsonEncode(out));
  stdout.writeln('Ручной каталог собран: дорам ${outDramas.length}, актёров ${rawActors.length}');
}
