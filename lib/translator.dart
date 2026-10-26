import 'models.dart';

abstract class TrHost {
  Map<int, String> get custom;
  Map<int, String> get tr;
  Map<int, String> get trSrc;
  Map<int, int> get tried;
  Iterable<Drama> get allDramas;
  Set<int> get userIds;
  void changed();
}

class Translator {
  final TrHost h;
  Translator(this.h);

  bool busy = false;
  int left = 0;

  Future<void> run() async {}
  Future<void> ensureOne(Drama d) async {}
  Future<void> ensureMany(List<Drama> l) async {}
  Future<SumRes?> summary(String en) async => null;
  static Future<String?> gtx(String text) async => null;
}
