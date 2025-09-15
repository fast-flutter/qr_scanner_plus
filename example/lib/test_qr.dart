import 'package:flutter/material.dart';
import 'package:qr_scanner_plus/qr_scanner_plus.dart';

class TestQr extends StatefulWidget {
  const TestQr({super.key});

  @override
  State<TestQr> createState() => _TestQrState();
}

class _TestQrState extends State<TestQr> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BarcodeScannerPlus example')),
      body: Center(child: QrScannerPlusView(_onResult, debug: true)),
    );
  }

  _onResult(List<Barcode> barcodes) {
    for (final barcode in barcodes) {
      print("@@@ ${barcode.type}");
      print("@@@ ${barcode.rawValue}");
    }
  }
}
