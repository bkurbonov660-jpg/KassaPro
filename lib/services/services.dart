import 'dart:convert';
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
    {'name': 'OpenRouter Auto Free (Лучшая доступная)', 'id': 'openrouter/free'},
    {'name': 'Meta Llama 3.3 70B (Мощный анализ)', 'id': 'meta-llama/llama-3.3-70b-instruct:free'},
    {'name': 'Google Gemini 2.0 Flash (Быстрая)', 'id': 'google/gemini-2.0-flash-exp:free'},
    {'name': 'DeepSeek R1 (Глубокое мышление)', 'id': 'deepseek/deepseek-r1:free'},
    {'name': 'Qwen 2.5 72B (Финансы и логика)', 'id': 'qwen/qwen-2.5-72b-instruct:free'},
  ];

  static Future<String> sendMessage({
    required String prompt,
    required String modelId,
    String systemPrompt = 'Ты умный персональный финансовый ассистент и консультант в приложении Kassapro. Отвечай емко, профессионально и на русском языке.',
  }) async {
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
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': prompt}
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data['choices'][0]['message']['content'] ?? 'ИИ не вернул текст.';
      } else {
        return 'Ошибка API (${res.statusCode}): ${res.body}';
      }
    } catch (e) {
      return 'Сбой соединения с ИИ: $e. Убедитесь в наличии интернета.';
    }
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
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('KASSAPRO | ФИНАНСОВЫЙ БЮЛЛЕТЕНЬ', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)),
                  pw.Text('Официальный реестр задолженностей и выплат', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(color: PdfColors.cyan800, thickness: 1.5, height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('МНЕ ДОЛЖНЫ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                  pw.Text('${theyOwe.toStringAsFixed(2)} $currency', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('Я ДОЛЖЕН', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                  pw.Text('${iOwe.toStringAsFixed(2)} $currency', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('БАЛАНС', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  pw.Text('${net >= 0 ? "+" : ""}${net.toStringAsFixed(2)} $currency', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: net >= 0 ? PdfColors.teal800 : PdfColors.red800)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Список записей', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Имя', 'Тип', 'Остаток', 'Дедлайн', 'Статус'],
            data: debts.map((d) => [
              d.personName,
              d.type == 'they_owe' ? 'Мне должны' : 'Я должен',
              '${d.amount.toStringAsFixed(2)} $currency',
              d.dueDate != null ? DateFormat('dd.MM.yyyy').format(d.dueDate!) : '—',
              d.isPaid ? 'Закрыт' : 'Активен',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
            cellHeight: 22,
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.center, 4: pw.Alignment.center},
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'kassapro_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
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

    final rows = debts.map((d) {
      final isThey = d.type == 'they_owe';
      final deadline = d.dueDate != null ? DateFormat('dd.MM.yyyy').format(d.dueDate!) : '—';
      return '''
      <tr>
        <td><strong>${d.personName}</strong></td>
        <td><span class="badge ${isThey ? 'badge-they' : 'badge-i'}">${isThey ? 'Мне должны' : 'Я должен'}</span></td>
        <td style="text-align: right; font-weight: bold;">${d.amount.toStringAsFixed(2)} $currency</td>
        <td>$deadline</td>
        <td><span class="badge ${d.isPaid ? 'badge-paid' : 'badge-active'}">${d.isPaid ? 'Погашен' : 'Активен'}</span></td>
      </tr>
      ''';
    }).join('');

    final html = '''
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kassapro — Финансовый отчет</title>
  <style>
    body { background: #0A0D14; color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 24px; margin: 0; }
    .card { background: #121622; border: 1px solid #1E2638; border-radius: 16px; padding: 20px; margin-bottom: 24px; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #06B6D4; padding-bottom: 12px; }
    .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-top: 16px; }
    .stat { background: #192030; border-radius: 12px; padding: 14px; text-align: center; }
    .stat-val { font-size: 20px; font-weight: bold; margin-top: 4px; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; }
    th { background: #06B6D4; color: #000; text-align: left; padding: 10px; font-size: 13px; }
    td { padding: 12px 10px; border-bottom: 1px solid #1E2638; font-size: 13px; }
    .badge { padding: 4px 8px; border-radius: 6px; font-size: 11px; font-weight: 600; }
    .badge-they { background: rgba(16,185,129,0.2); color: #10B981; }
    .badge-i { background: rgba(244,63,94,0.2); color: #F43F5E; }
    .badge-paid { background: rgba(148,163,184,0.2); color: #94A3B8; }
    .badge-active { background: rgba(6,182,212,0.2); color: #06B6D4; }
  </style>
</head>
<body>
  <div class="card header">
    <div>
      <h2 style="margin: 0; color: #06B6D4;">Kassapro Pro Report</h2>
      <small style="color: #94A3B8;">Сводка задолженностей и обязательств</small>
    </div>
    <div style="color: #94A3B8; font-size: 13px;">${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}</div>
  </div>

  <div class="card grid">
    <div class="stat"><small style="color: #10B981;">МНЕ ДОЛЖНЫ</small><div class="stat-val" style="color: #10B981;">${theyOwe.toStringAsFixed(2)} $currency</div></div>
    <div class="stat"><small style="color: #F43F5E;">Я ДОЛЖЕН</small><div class="stat-val" style="color: #F43F5E;">${iOwe.toStringAsFixed(2)} $currency</div></div>
    <div class="stat"><small style="color: #06B6D4;">БАЛАНС</small><div class="stat-val">${net >= 0 ? "+" : ""}${net.toStringAsFixed(2)} $currency</div></div>
  </div>

  <div class="card">
    <h3 style="margin-top: 0;">Реестр должников</h3>
    <table>
      <thead><tr><th>Имя</th><th>Направление</th><th style="text-align: right;">Сумма</th><th>Дедлайн</th><th>Статус</th></tr></thead>
      <tbody>$rows</tbody>
    </table>
  </div>
</body>
</html>
''';

    await Printing.sharePdf(bytes: utf8.encode(html), filename: 'kassapro_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.html');
  }
}
