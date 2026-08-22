import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRExportModal extends StatelessWidget {
  final String data;
  final String title;

  const QRExportModal({super.key, required this.data, this.title = 'Экспорт данных'});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Отсканируйте код на другом устройстве'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 200,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
