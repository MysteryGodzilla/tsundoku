import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../books/isbn.dart';

/// Scans a book's barcode and returns its ISBN-13 (or [typeInstead]).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  static const typeInstead = 'type-instead';

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.ean13], facing: CameraFacing.back);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detected(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue ?? '';
      if (isBookBarcode(v)) {
        _done = true;
        Navigator.of(context).pop(v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan the barcode'),
        actions: [
          IconButton(tooltip: 'Torch', icon: const Icon(Icons.flashlight_on_outlined), onPressed: () => _controller.toggleTorch()),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: _controller,
          onDetect: _detected,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('The camera isn\'t available. You can type the ISBN instead.',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 280,
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 2), borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 32,
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Point the camera at the barcode on the back of the book',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 16),
              FilledButton.tonal(
                style: FilledButton.styleFrom(backgroundColor: cs.surface, foregroundColor: cs.onSurface),
                onPressed: () => Navigator.of(context).pop(ScanScreen.typeInstead),
                child: const Text('Type the ISBN instead'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
