import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Resp {
  final int code;
  final dynamic data;
  Resp(this.code, this.data);
}

class Net {
  static const String ua = 'DoramaPulse/2.3 (Android; bkuronov660@gmail.com)';
  static Future<Resp> get(Uri u, {int retries = 2, Duration timeout = const Duration(seconds: 30)}) async {
    var code = 0;
    for (var i = 0; i <= retries; i++) {
      try {
        final r = await http.get(u, headers: {'User-Agent': ua, 'Accept': 'application/json'}).timeout(timeout);
        code = r.statusCode;
        if (code == 200) {
          try { return Resp(200, jsonDecode(utf8.decode(r.bodyBytes))); }
          catch (_) { return Resp(-2, null); }
        }
        if (code == 404) return Resp(404, null);
        if (code == 429) { await Future.delayed(Duration(seconds: 3 + i * 3)); continue; }
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (_) {
        code = 0; await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    return Resp(code, null);
  }
  static Future<dynamic> json(Uri u, {int retries = 2, Duration timeout = const Duration(seconds: 30)}) async {
    final r = await get(u, retries: retries, timeout: timeout);
    return r.code == 200 ? r.data : null;
  }
  static Future<void> sleep(int ms) => Future.delayed(Duration(milliseconds: ms));
}
