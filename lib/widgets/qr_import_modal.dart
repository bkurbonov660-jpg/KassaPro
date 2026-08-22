import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRImportModal extends StatefulWidget {
  final Function(String data) onImport;

  const QRImportModal({super.key, required this.onImport});

  @override
  State<QRImportModal> createState() => _QRImportModalState();
}

class _QRImportModalState extends State<QRImportModal> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Импорт данных (QR)'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: MobileScanner(
          onDetect: (capture) {
            if (_isScanned) return;
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _isScanned = true;
                widget.onImport(barcode.rawValue!);
                Navigator.pop(context);
                break;
              }
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
