const Map<String, String> _w = {
  'love':'любовь','secret':'тайна','doctor':'доктор','king':'король','queen':'королева',
  'prince':'принц','palace':'дворец','night':'ночь','day':'день','heart':'сердце',
  'my':'мой','your':'твой','our':'наш','dear':'дорогой','first':'первый','last':'последний',
  'new':'новый','old':'старый','family':'семья','school':'школа','life':'жизнь','death':'смерть',
  'ghost':'призрак','demon':'демон','world':'мир','beautiful':'прекрасный','girl':'девушка',
  'boy':'парень','woman':'женщина','man':'мужчина','wife':'жена','husband':'муж','mother':'мать',
  'father':'отец','son':'сын','daughter':'дочь','brother':'брат','sister':'сестра','friend':'друг',
  'lover':'возлюбленный','marriage':'брак','divorce':'развод','business':'бизнес','war':'война',
  'police':'полиция','detective':'детектив','killer':'убийца','crime':'преступление',
  'lawyer':'адвокат','judge':'судья','court':'суд','revenge':'месть','glory':'слава',
  'time':'время','moon':'луна','sun':'солнце','star':'звезда','sky':'небо','sea':'море',
  'river':'река','flower':'цветок','snow':'снег','summer':'лето','winter':'зима','spring':'весна',
  'dream':'мечта','game':'игра','fire':'огонь','blood':'кровь','sword':'меч','dragon':'дракон',
  'house':'дом','hotel':'отель','city':'город','street':'улица','story':'история','memory':'память',
  'promise':'обещание','wish':'желание','miracle':'чудо','magic':'магия','witch':'ведьма',
  'hero':'герой','master':'мастер','lady':'леди','young':'молодой','little':'маленький',
  'great':'великий','good':'хороший','evil':'зло','return':'возвращение','again':'снова',
  'forever':'навсегда','season':'сезон','money':'деньги','hospital':'больница','music':'музыка',
  'dance':'танец','movie':'фильм','taxi':'такси','chef':'шеф-повар','food':'еда',
};
const Set<String> _skip = {'the','a','an','of','to','in','on','at','for','and','with'};
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String localTranslate(String en) {
  final out = <String>[];
  for (final raw in en.split(RegExp(r'\s+'))) {
    final clean = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.isEmpty) continue;
    final low = clean.toLowerCase();
    if (_skip.contains(low) && out.isNotEmpty) continue;
    if (_w.containsKey(low)) out.add(_w[low]!);
    else if (RegExp(r'^[0-9]+$').hasMatch(clean)) out.add(clean);
    else out.add(_cap(clean));
  }
  if (out.isEmpty) return en;
  return _cap(out.join(' '));
}
