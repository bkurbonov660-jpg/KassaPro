import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class AIService {
  static final String _encKey = 'c2stb3ItdjEtYjJiZjZjY2UyNGExOGRlMDYzN2I3M2FlNGZhZmQ4MmVkZGY4MDhkNjk4ZDk1NWIxOTdmNGMxNWM2NWE5ZjczOQ==';
  static String get _apiKey => utf8.decode(base64Decode(_encKey));

  static const List<Map<String, String>> freeModels = [
    {'name': 'Автоматический выбор (OpenRouter Free)', 'id': 'openrouter/free'},
    {'name': 'Meta Llama 3.3 70B Free', 'id': 'meta-llama/llama-3.3-70b-instruct:free'},
    {'name': 'Google Gemini 2.0 Flash Free', 'id': 'google/gemini-2.0-flash-exp:free'},
    {'name': 'DeepSeek R1 Free', 'id': 'deepseek/deepseek-r1:free'},
    {'name': 'Qwen 2.5 72B Free', 'id': 'qwen/qwen-2.5-72b-instruct:free'},
  ];

  // Готовые шаблоны сообщений для работы офлайн
  static const List<Map<String, String>> offlineTemplates = [
    {
      'title': 'Вежливое напоминание о сроке',
      'text': 'Здравствуйте! Напоминаю, что подходит срок возврата суммы {amount} {currency}. Буду благодарен за обратную связь.'
    },
    {
      'title': 'Сообщение с реквизитами для перевода',
      'text': 'Салам! По поводу долга {amount} {currency} — перевод можно сделать на карту / кошелек: [Номер карты]. Спасибо!'
    },
    {
      'title': 'Предложение графика выплат',
      'text': 'Привет! Понимаю текущую ситуацию. Давай согласуем возврат остатка {amount} {currency} частями, например, по 20-30% в неделю.'
    },
    {
      'title': 'Официальное уведомление о просрочке',
      'text': 'Уведомление: задолженность в размере {amount} {currency} просрочена. Прошу связаться для закрытия обязательства.'
    }
  ];

  static Future<Map<String, dynamic>> sendSmartMessage({
    required String prompt,
    required String modelId,
    required List<Debt> debts,
    required String currency,
  }) async {
    // 1. Попытка подключения к OpenRouter
    try {
      final res = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': modelId,
          'messages': [
            {
              'role': 'system',
              'content': 'Ты персональный финансовый аудитор в приложении Kassapro. Пиши строго по делу, деловым языком, без лишних вступлений.'
            },
            {'role': 'user', 'content': prompt}
          ],
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return {
          'text': data['choices'][0]['message']['content'] ?? 'ИИ сформировал ответ.',
          'isOffline': false,
        };
      }
    } catch (_) {
      // Игнорируем сетевые ошибки и автоматически переключаемся на офлайн-модуль
    }

    // 2. Локальный интеллектуальный офлайн-анализ (работает без интернета 100%)
    return {
      'text': _generateOfflineAnalysis(debts, currency),
      'isOffline': true,
    };
  }

  static String _generateOfflineAnalysis(List<Debt> debts, String currency) {
    double theyOwe = 0;
    double iOwe = 0;
    int activeCount = 0;
    String topDebtor = '—';
    double topAmount = 0;

    for (var d in debts) {
      if (!d.isPaid) {
        activeCount++;
        if (d.type == 'they_owe') {
          theyOwe += d.amount;
          if (d.amount > topAmount) {
            topAmount = d.amount;
            topDebtor = d.personName;
          }
        }
        if (d.type == 'i_owe') iOwe += d.amount;
      }
    }

    final net = theyOwe - iOwe;
    return '''
[ОФЛАЙН ИИ-АУДИТ ПОРТФЕЛЯ]
• Финансовая позиция:
  - Вам должны: ${theyOwe.toStringAsFixed(2)} $currency
  - Вы должны: ${iOwe.toStringAsFixed(2)} $currency
  - Сальдо (чистый остаток): ${net >= 0 ? "+" : ""}${net.toStringAsFixed(2)} $currency

• Рекомендация по ликвидности:
  ${net >= 0 ? "Положительный баланс. Приоритет — контроль возвратов." : "Отрицательное сальдо. Рекомендуется первоочередное погашение своих обязательств."}

• Ключевое обязательство:
  Крупнейший долг: $topDebtor ($topAmount $currency).
  
(Для отправки напоминаний используйте вкладку "Шаблоны").
''';
  }
}

class ReportExporter {
  static Future<void> exportPdf(List<Debt> debts, String currency) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    double theyOwe = 0;
    double iOwe = 0;
    for (var d in debts) {
      if (!d.isPaid) {
        if (d.type == 'they_owe') theyOwe += d.amount;
        if (d.type == 'i_owe') iOwe += d.amount;
      }
    }
    double net = theyOwe - iOwe;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('KASSAPRO EXECUTIVE LEDGER', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                  pw.Text('Акт сверки взаиморасчетов и долговых обязательств', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.Divider(color: PdfColors.black, thickness: 1, height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text('Вам должны: ${theyOwe.toStringAsFixed(2)} $currency', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Вы должны: ${iOwe.toStringAsFixed(2)} $currency', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Сальдо: ${net >= 0 ? "+" : ""}${net.toStringAsFixed(2)} $currency', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Контакт', 'Тип', 'Сумма', 'Дедлайн', 'Статус'],
            data: debts.map((d) => [
              d.personName,
              d.type == 'they_owe' ? 'Дебитор (мне)' : 'Кредитор (я)',
              '${d.amount.toStringAsFixed(2)} $currency',
              d.dueDate != null ? DateFormat('dd.MM.yyyy').format(d.dueDate!) : '—',
              d.isPaid ? 'Закрыт' : 'Активен',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
            cellHeight: 22,
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'kassapro_ledger_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
  }

  static Future<void> exportHtml(List<Debt> debts, String currency) async {
    double theyOwe = 0;
    double iOwe = 0;
    for (var d in debts) {
      if (!d.isPaid) {
        if (d.type == 'they_owe') theyOwe += d.amount;
        if (d.type == 'i_owe') iOwe += d.amount;
      }
    }
    double net = theyOwe - iOwe;

    // Группируем долги по людям для отчета
    Map<String, List<Debt>> grouped = {};
    for (var d in debts) {
      final key = d.personName.trim();
      grouped.putIfAbsent(key, () => []).add(d);
    }

    final tableRows = grouped.entries.map((entry) {
      final name = entry.key;
      final subList = entry.value;
      final subRows = subList.map((d) {
        return '''
        <div style="padding: 6px 0; border-bottom: 1px dotted #334155; display: flex; justify-content: space-between; font-size: 13px;">
          <span>• ${d.type == 'they_owe' ? 'Мне должен' : 'Я должен'} (${DateFormat('dd.MM.yyyy').format(d.createdAt)}): ${d.note.isNotEmpty ? d.note : 'Без описания'}</span>
          <span style="font-weight: bold; color: ${d.type == 'they_owe' ? '#10B981' : '#EF4444'};">${d.amount.toStringAsFixed(2)} $currency ${d.isPaid ? '[ПОГАШЕН]' : ''}</span>
        </div>
        ''';
      }).join('');

      return '''
      <tr style="border-bottom: 1px solid #1E293B;">
        <td style="padding: 14px; font-weight: bold; font-size: 15px; vertical-align: top;">${name}</td>
        <td style="padding: 14px;">${subRows}</td>
      </tr>
      ''';
    }).join('');

    final html = '''
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <title>Kassapro Executive Statement</title>
  <style>
    body { background: #0B0E14; color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; padding: 28px; margin: 0; }
    .container { max-width: 900px; margin: 0 auto; background: #121620; border: 1px solid #232B3E; border-radius: 12px; padding: 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    .header { display: flex; justify-content: space-between; align-items: flex-end; border-bottom: 1px solid #232B3E; padding-bottom: 16px; margin-bottom: 20px; }
    .stats { display: flex; gap: 16px; margin-bottom: 24px; }
    .box { flex: 1; background: #181E2C; border: 1px solid #283248; border-radius: 8px; padding: 14px; text-align: center; }
    .box small { color: #94A3B8; font-size: 11px; text-transform: uppercase; font-weight: 600; }
    .box div { font-size: 20px; font-weight: bold; margin-top: 6px; }
    table { width: 100%; border-collapse: collapse; margin-top: 10px; }
    th { background: #181E2C; color: #94A3B8; text-align: left; padding: 12px 14px; font-size: 12px; text-transform: uppercase; border-bottom: 1px solid #232B3E; }
    @media print { body { background: #fff; color: #000; } .container { border: none; box-shadow: none; } }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div>
        <h2 style="margin: 0; font-size: 20px; letter-spacing: 0.5px;">KASSAPRO EXECUTIVE STATEMENT</h2>
        <div style="color: #94A3B8; font-size: 12px; margin-top: 4px;">Сводный реестр взаиморасчетов</div>
      </div>
      <div style="color: #94A3B8; font-size: 12px;">${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}</div>
    </div>
    <div class="stats">
      <div class="box"><small>Мне должны</small><div style="color: #10B981;">${theyOwe.toStringAsFixed(2)} $currency</div></div>
      <div class="box"><small>Я должен</small><div style="color: #EF4444;">${iOwe.toStringAsFixed(2)} $currency</div></div>
      <div class="box"><small>Чистое сальдо</small><div style="color: ${net >= 0 ? '#10B981' : '#EF4444'};">${net >= 0 ? "+" : ""}${net.toStringAsFixed(2)} $currency</div></div>
    </div>
    <table>
      <thead><tr><th style="width: 28%;">Контакт / Лицо</th><th>Взаиморасчеты и займы</th></tr></thead>
      <tbody>${tableRows}</tbody>
    </table>
  </div>
</body>
</html>
''';

    await Printing.sharePdf(bytes: utf8.encode(html), filename: 'kassapro_statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.html');
  }
}
