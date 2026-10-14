import 'dict_data.dart';

String nk(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
final RegExp _cyr = RegExp(r'[а-яёА-ЯЁ]');
bool hasCyr(String s) => _cyr.hasMatch(s);

final Map<String, String> _rud = _build();
Map<String, String> _build() {
  final m = <String, String>{};
  for (final e in kDict) {
    for (final k in e[0].split('|')) {
      final n = nk(k);
      if (n.isNotEmpty) m[n] = e[1];
    }
  }
  return m;
}
String? dictLookup(String en) {
  final n = nk(en);
  if (n.isEmpty) return null;
  return _rud[n];
}
int get dictSize => kDict.length;
