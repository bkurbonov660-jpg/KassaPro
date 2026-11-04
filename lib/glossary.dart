import 'dict.dart';

// Вместо глупого пословного перевода возвращаем точное русское название из словаря,
// либо оставляем чистое оригинальное название до получения данных из Кинопоиска / Викиданных / ИИ.
String localTranslate(String en) {
  final d = dictLookup(en);
  if (d != null && d.isNotEmpty) return d;
  return en.trim();
}
