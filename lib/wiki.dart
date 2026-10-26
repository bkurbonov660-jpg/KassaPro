import 'models.dart';

class Wiki {
  static const Map<String, String> cMap = {'Q884': 'KR'};
  static Future<Map<String, String>?> byImdb(List<String> ids) async => null;
  static Future<Map<String, String>?> byEnglish(List<String> names) async => null;
  static Future<List<Map<String, dynamic>>?> announced(int fromYear, {int limit = 700, int offset = 0}) async => null;
  static Future<Map<String, String>?> actorsRu(List<String> names) async => <String, String>{};
  static Future<List<Map<String, dynamic>>?> actorShows(String name) async => null;
  static Future<List<Map<String, String>>?> actorAwards(String name) async => null;
  static Future<Map<String, List<Map<String, String>>>?> batchActorAwards(List<String> names) async => <String, List<Map<String, String>>>{};
  static Future<List<RuHit>?> searchRu(String q) async => null;
  static Future<List<Map<String, String>>?> ruSearch(String en) async => null;
  static String? pick(String en, List<Map<String, String>> r) => null;
}
