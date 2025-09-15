import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'test_qr.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('BarcodeScannerPlus example')),
        body: ElevatedButton(
          child: const Text("Click"),
          onPressed: () {
            Get.to(const TestQr());
          },
        ),
      ),
    );
  }
}
