const Map<String, Map<String, String>> appStrings = {
  'navCash': {'ru': 'Касса', 'tj': 'Хазина', 'en': 'Register'},
  'navProducts': {'ru': 'Товары', 'tj': 'Молҳо', 'en': 'Products'},
  'navHistory': {'ru': 'Календарь', 'tj': 'Тақвим', 'en': 'Calendar'},
  'navDebts': {'ru': 'Долги', 'tj': 'Қарзҳо', 'en': 'Debts'},
  'navShift': {'ru': 'Меню', 'tj': 'Меню', 'en': 'Menu'},
  'search': {'ru': 'Поиск товара...', 'tj': 'Ҷустуҷӯи мол...', 'en': 'Search product...'},
  'cart': {'ru': 'Корзина', 'tj': 'Сабад', 'en': 'Cart'},
  'sell': {'ru': 'Продать', 'tj': 'Фурӯхтан', 'en': 'Sell'},
  'addProduct': {'ru': 'Добавить вручную', 'tj': 'Дастӣ илова кардан', 'en': 'Add Manual'},
  'scanProduct': {'ru': 'Сканер штрих/QR', 'tj': 'Сканери штрих/QR', 'en': 'Scan Barcode/QR'},
  'productName': {'ru': 'Название товара', 'tj': 'Номи мол', 'en': 'Product Name'},
  'sellingPrice': {'ru': 'Цена продажи', 'tj': 'Нархи фурӯш', 'en': 'Selling Price'},
  'stock': {'ru': 'Остаток', 'tj': 'Боқимонда', 'en': 'Stock'},
  'barcode': {'ru': 'Штрих-код (необязательно)', 'tj': 'Штрих-код (ихтиёрӣ)', 'en': 'Barcode (Optional)'},
  'save': {'ru': 'Сохранить', 'tj': 'Сабт кардан', 'en': 'Save'},
  'debtors': {'ru': 'Должники', 'tj': 'Қарздорон', 'en': 'Debtors'},
  'addDebt': {'ru': 'Выдать в долг', 'tj': 'Ба қарз додан', 'en': 'Add Debt'},
  'clientName': {'ru': 'Имя клиента', 'tj': 'Номи муштарӣ', 'en': 'Client Name'},
  'amount': {'ru': 'Сумма', 'tj': 'Маблағ', 'en': 'Amount'},
  'pay': {'ru': 'Погасить', 'tj': 'Пардохт', 'en': 'Pay off'},
  'paid': {'ru': 'Оплачено', 'tj': 'Пардохт шуд', 'en': 'Paid'},
  'clearDB': {'ru': 'Сброс всех данных', 'tj': 'Тоза кардани база', 'en': 'Clear all data'},
  'training': {'ru': 'Пройти обучение', 'tj': 'Омӯзишро гузаштан', 'en': 'Start Training'},
  'exportImport': {'ru': 'Резервная копия (Перенос)', 'tj': 'Нусхаи эҳтиётӣ (Интиқол)', 'en': 'Backup (Transfer)'},
};
String t(String key, String lang) {
  final map = appStrings[key];
  if (map == null) return key;
  return map[lang] ?? map['ru'] ?? key;
}
String getCurrency(String lang) {
  if (lang == 'tj') return 'сом.';
  if (lang == 'en') return '\$';
  return '₽';
}
