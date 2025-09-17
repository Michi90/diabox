import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isDetecting = false; // Flag to prevent multiple detections

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode scannen'),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on), // Always show flash_on icon
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.camera_rear), // Always show camera_rear icon
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          if (_isDetecting) return; // Prevent multiple detections
          _isDetecting = true;

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? barcode = barcodes.first.rawValue;
            print('Scanned barcode rawValue: $barcode');
            if (barcode != null) {
              cameraController.stop(); // Stop camera immediately
              Navigator.pop(context, barcode); // Return the scanned barcode
            } else {
              cameraController.stop(); // Stop camera immediately
              Navigator.pop(context, '');
            }
          } else {
            cameraController.stop(); // Stop camera immediately
            Navigator.pop(context, '');
          }
        },
      ),
    );
  }
}
