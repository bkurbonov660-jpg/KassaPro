class OpenRouter {
  static String key = '';
  static bool webPlugin = false;
  static bool badKey = true;
  static bool lastOk = false;
  static String lastModel = '';
  static String lastError = '';

  static Future<List<String>> freeModels() async => <String>[];
  static dynamic extractJson(String s) => null;
  static Future<String?> chat(String system, String user, {int maxTokens = 900}) async => null;
  static void resetErrors() {}
}
