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

const Map<String, String> _actorAliases = {
  'goyunjeong': 'goyounjung',
  'goyoonjung': 'goyounjung',
  'koyunjung': 'goyounjung',
  'koyunjeong': 'goyounjung',
  'koyoonjung': 'goyounjung',
  'kimyeonggwang': 'kimyoungkwang',
  'chaesubin': 'chaesoobin',
  'kimseonho': 'kimseonho',
  'kimsunho': 'kimseonho',
  'kimhyeyun': 'kimhyeyoon',
  'jujihun': 'jujihoon',
  'gokyoungpyo': 'gokyungpyo',
  'kokyungpyo': 'gokyungpyo',
  'woodohwan': 'woodohwan',
  'udohwan': 'woodohwan',
  'namgungmin': 'namkoongmin',
  'ryujunyeol': 'ryujunyeol',
  'ryujoonyeol': 'ryujunyeol',
  'songgang': 'songkang',
  'byeonuseok': 'byeonwooseok',
  'byunwooseok': 'byeonwooseok',
  'leedohyun': 'leedohyun',
  'idohyeon': 'leedohyun',
  'parkbogum': 'parkbogum',
  'pakbogom': 'parkbogum',
  'hansohee': 'hansohee',
  'hansohui': 'hansohee',
  'hwanginyeop': 'hwanginyoup',
  'chaeeunwoo': 'chaeunwoo',
  'chaeunu': 'chaeunwoo',
  'imsiwan': 'yimsiwan',
  'limsiwan': 'yimsiwan',
  'siwan': 'yimsiwan',
  'yimsiwan': 'yimsiwan',
  'seolina': 'seolinah',
  'seolinah': 'seolinah',
  'sorina': 'seolinah',
  'kimjeonghyeon': 'kimjunghyun',
  'kimjunghyeon': 'kimjunghyun',
  'kimjunghyun': 'kimjunghyun',
  'yeonwoo': 'yeonwoo',
  'yeonu': 'yeonwoo',
  'leedabin': 'yeonwoo',
  'yeonwooleedabin': 'yeonwoo',
  'kiminkwon': 'kiminkwon',
  'kimingwon': 'kiminkwon',
};

const Map<String, String> _ruActorAliases = {
  'ёну': 'yeonwoo',
  'ену': 'yeonwoo',
  'ли да бин': 'yeonwoo',
  'ёну (ли да бин)': 'yeonwoo',
  'ену (ли да бин)': 'yeonwoo',
  'ким джон хён': 'kimjunghyun',
  'ким джон хен': 'kimjunghyun',
  'им си ван': 'yimsiwan',
  'соль ин а': 'seolinah',
  'ким ин гвон': 'kiminkwon',
  'ким ён гван': 'kimyoungkwang',
  'ким ен гван': 'kimyoungkwang',
  'чхэ су бин': 'chaesoobin',
  'го юн чжон': 'goyounjung',
  'ким сон хо': 'kimseonho',
};

const Map<String, String> _actorWikiName = {
  'goyounjung': 'Go Youn-jung',
  'kimyoungkwang': 'Kim Young-kwang',
  'chaesoobin': 'Chae Soo-bin',
  'kimseonho': 'Kim Seon-ho',
  'parkshinhye': 'Park Shin-hye',
  'kimhyeyoon': 'Kim Hye-yoon',
  'parkeunbin': 'Park Eun-bin',
  'chaeunwoo': 'Cha Eun-woo',
  'leejaewook': 'Lee Jae-wook',
  'namkoongmin': 'Namkoong Min',
  'hyunbin': 'Hyun Bin',
  'sonyejin': 'Son Ye-jin',
  'jichangwook': 'Ji Chang-wook',
  'songkang': 'Song Kang',
  'byeonwooseok': 'Byeon Woo-seok',
  'leedohyun': 'Lee Do-hyun',
  'parkbogum': 'Park Bo-gum',
  'hansohee': 'Han So-hee',
  'hwanginyoup': 'Hwang In-youp',
  'rowoon': 'Rowoon',
  'yimsiwan': 'Yim Si-wan',
  'seolinah': 'Seol In-ah',
  'kimjunghyun': 'Kim Jung-hyun',
  'yeonwoo': 'Yeonwoo',
  'kiminkwon': 'Kim In-kwon',
  'choijinho': 'Choi Jin-ho',
  'hongeunhee': 'Hong Eun-hee',
  'parkahin': 'Park Ah-in',
  'ryuseungsoo': 'Ryu Seung-soo',
  'kimkibang': 'Kim Ki-bang',
};

String ak(String s) {
  final k = nk(s);
  if (k.isNotEmpty) return _actorAliases[k] ?? k;
  final rl = s.trim().toLowerCase().replaceAll('ё', 'е');
  return _ruActorAliases[rl] ?? _ruActorAliases[s.trim().toLowerCase()] ?? '';
}

String wikiActorName(String s) {
  final k = ak(s);
  return _actorWikiName[k] ?? s;
}

String _ye(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll('подзариди', 'подзаряди')
    .replaceAll('зариди', 'заряди');

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
