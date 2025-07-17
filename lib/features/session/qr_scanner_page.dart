import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../session/map_selector_page.dart';

class QRCodeScannerPage extends ConsumerStatefulWidget {
  const QRCodeScannerPage({super.key});

  @override
  ConsumerState<QRCodeScannerPage> createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends ConsumerState<QRCodeScannerPage> {
  bool _isScanned = false;

  void _handleQRCode(String qrData) {
    if (_isScanned) return; // prevent double scans
    _isScanned = true;

    final uri = Uri.tryParse(qrData);
    final driverId = uri?.queryParameters['driverId'];

    if (driverId != null && driverId.isNotEmpty) {
      // Optional: show toast/snackbar
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Driver ID: $driverId scanned')));

      // ✅ Navigate to destination selector with driver ID
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MapSelectorPage(driverId: driverId)),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid QR code')));
      setState(() => _isScanned = false); // Allow re-scanning
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Driver QR Code'),
        backgroundColor: const Color(0xFF667eea),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.first;
          final qrData = barcode.rawValue;
          if (qrData != null) _handleQRCode(qrData);
        },
      ),
    );
  }
}
