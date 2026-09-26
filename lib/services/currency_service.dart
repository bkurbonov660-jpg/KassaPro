import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyItem {
  final String code;
  final String name;
  final String flag;
  final String symbol;

  const CurrencyItem({
    required this.code,
    required this.name,
    required this.flag,
    required this.symbol,
  });
}

class CurrencyService {
  static const List<CurrencyItem> popularCurrencies = [
    CurrencyItem(code: 'TJS', name: 'Таджикский сомони', flag: '🇹🇯', symbol: 'с.'),
    CurrencyItem(code: 'USD', name: 'Доллар США', flag: '🇺🇸', symbol: r'$'),
    CurrencyItem(code: 'RUB', name: 'Российский рубль', flag: '🇷🇺', symbol: '₽'),
    CurrencyItem(code: 'EUR', name: 'Евро', flag: '🇪🇺', symbol: '€'),
    CurrencyItem(code: 'CNY', name: 'Китайский юань', flag: '🇨🇳', symbol: '¥'),
    CurrencyItem(code: 'KZT', name: 'Казахстанский тенге', flag: '🇰🇿', symbol: '₸'),
    CurrencyItem(code: 'UZS', name: 'Узбекский сум', flag: '🇺🇿', symbol: 'сўм'),
    CurrencyItem(code: 'TRY', name: 'Турецкая лира', flag: '🇹🇷', symbol: '₺'),
    CurrencyItem(code: 'AED', name: 'Дирхам ОАЭ', flag: '🇦🇪', symbol: 'AED'),
    CurrencyItem(code: 'GBP', name: 'Британский фунт', flag: '🇬🇧', symbol: '£'),
    CurrencyItem(code: 'SAR', name: 'Саудовский риял', flag: '🇸🇦', symbol: 'SR'),
    CurrencyItem(code: 'CHF', name: 'Швейцарский франк', flag: '🇨🇭', symbol: 'CHF'),
    CurrencyItem(code: 'JPY', name: 'Японская иена', flag: '🇯🇵', symbol: '¥'),
    CurrencyItem(code: 'CAD', name: 'Канадский доллар', flag: '🇨🇦', symbol: r'C$'),
    CurrencyItem(code: 'GEL', name: 'Грузинский лари', flag: '🇬🇪', symbol: '₾'),
    CurrencyItem(code: 'KGS', name: 'Кыргызский сом', flag: '🇰🇬', symbol: 'сом'),
    CurrencyItem(code: 'INR', name: 'Индийская рупия', flag: '🇮🇳', symbol: '₹'),
    CurrencyItem(code: 'KRW', name: 'Южнокорейская вона', flag: '🇰🇷', symbol: '₩'),
  ];

  static const Map<String, double> fallbackRates = {
    'USD': 1.0,
    'TJS': 10.92,
    'RUB': 92.50,
    'EUR': 0.92,
    'CNY': 7.23,
    'KZT': 475.0,
    'UZS': 12650.0,
    'TRY': 33.80,
    'AED': 3.67,
    'GBP': 0.77,
    'SAR': 3.75,
    'CHF': 0.86,
    'JPY': 148.5,
    'CAD': 1.36,
    'GEL': 2.70,
    'KGS': 85.50,
    'INR': 83.70,
    'KRW': 1340.0,
  };

  static Map<String, double> currentRates = Map.from(fallbackRates);
  static DateTime? lastUpdated;
  static bool isOnline = false;

  static Future<void> loadCachedRates() async {
    try {
      final p = await SharedPreferences.getInstance();
      final savedStr = p.getString('cached_rates_json');
      final savedTime = p.getString('cached_rates_time');
      if (savedStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedStr);
        currentRates = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
      if (savedTime != null) {
        lastUpdated = DateTime.tryParse(savedTime);
      }
    } catch (_) {}
  }

  static Future<bool> fetchLiveRates() async {
    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/USD');
      final res = await http.get(uri).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['result'] == 'success' && data['rates'] != null) {
          final Map<String, dynamic> r = data['rates'];
          currentRates = r.map((k, v) => MapEntry(k, (v as num).toDouble()));
          if (!currentRates.containsKey('TJS') || currentRates['TJS'] == 0) {
            currentRates['TJS'] = 10.92;
          }
          lastUpdated = DateTime.now();
          isOnline = true;

          final p = await SharedPreferences.getInstance();
          await p.setString('cached_rates_json', jsonEncode(currentRates));
          await p.setString('cached_rates_time', lastUpdated!.toIso8601String());
          return true;
        }
      }
    } catch (_) {
      try {
        final uri2 = Uri.parse('https://api.exchangerate-api.com/v4/latest/USD');
        final res2 = await http.get(uri2).timeout(const Duration(seconds: 7));
        if (res2.statusCode == 200) {
          final data = jsonDecode(res2.body);
          if (data['rates'] != null) {
            final Map<String, dynamic> r = data['rates'];
            currentRates = r.map((k, v) => MapEntry(k, (v as num).toDouble()));
            if (!currentRates.containsKey('TJS') || currentRates['TJS'] == 0) {
              currentRates['TJS'] = 10.92;
            }
            lastUpdated = DateTime.now();
            isOnline = true;
            final p = await SharedPreferences.getInstance();
            await p.setString('cached_rates_json', jsonEncode(currentRates));
            await p.setString('cached_rates_time', lastUpdated!.toIso8601String());
            return true;
          }
        }
      } catch (_) {}
    }
    isOnline = false;
    return false;
  }

  static double convert(double amount, String fromCode, String toCode) {
    final fromRate = currentRates[fromCode] ?? fallbackRates[fromCode] ?? 1.0;
    final toRate = currentRates[toCode] ?? fallbackRates[toCode] ?? 1.0;
    if (fromRate == 0) return 0.0;
    final inUsd = amount / fromRate;
    return inUsd * toRate;
  }
}
