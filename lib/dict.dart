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

const Map<String, String> _actorAliases = {};
const Map<String, String> _ruActorAliases = {};
const Map<String, String> _actorWikiName = {};

String ak(String s) {
  final k = nk(s);
  if (k.isNotEmpty) return _actorAliases[k] ?? k;
  final rl = s.trim().toLowerCase().replaceAll('ё', 'е');
  return _ruActorAliases[rl] ?? rl.replaceAll(RegExp(r'[^а-яa-z0-9]+'), '');
}

String wikiActorName(String s) {
  final k = ak(s);
  return _actorWikiName[k] ?? s;
}

String _ye(String s) => s.toLowerCase().replaceAll('ё', 'е');

List<List<String>> dictSearch(String q) {
  final ql = _ye(q.trim());
  if (ql.length < 2) return <List<String>>[];
  final out = <List<String>>[];
  for (final e in kDict) {
    final hitMain = _ye(e[1]).contains(ql);
    final hitAlias = e.length > 3 && _ye(e[3]).contains(ql);
    if (hitMain || hitAlias) {
      out.add([e.length > 2 ? e[2] : e[0].split('|').first, e[1]]);
    }
    if (out.length >= 8) break;
  }
  return out;
}
