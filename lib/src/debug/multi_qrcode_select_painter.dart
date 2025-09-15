import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import 'coordinates_translator.dart';

class MultiQrcodeSelectPainter extends CustomPainter {
  MultiQrcodeSelectPainter(
    this.barcodes,
    this.absoluteImageSize,
    this.rotation,
    this.onSelect,
  );

  final List<Barcode> barcodes;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final Function(Barcode barcode) onSelect;

  //store the barcode rect in the screen coordinate system
  List<Map<Rect, Barcode>> _barcodesOnScreen = [];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 16.0
      ..color = Color.fromARGB(225, 79, 193, 154);

    final Paint paintWhite = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 3.0
      ..color = Color.fromARGB(200, 255, 255, 255);

    final Paint background = Paint()..color = Color(0x99000000);

    for (final Barcode barcode in barcodes) {
      final ParagraphBuilder builder = ParagraphBuilder(
        ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: 16,
            textDirection: TextDirection.ltr),
      );
      builder
          .pushStyle(ui.TextStyle(color: Colors.black, background: background));
      builder.pop();

      // Store the points for the bounding box
      double left = double.infinity;
      double top = double.infinity;
      double right = double.negativeInfinity;
      double bottom = double.negativeInfinity;

      final cornerPoints = barcode.cornerPoints;
      final boundingBox = barcode.boundingBox;
      if (cornerPoints == null) {
        if (boundingBox != null) {
          left =
              translateX(boundingBox.left, rotation, size, absoluteImageSize);
          top = translateY(boundingBox.top, rotation, size, absoluteImageSize);
          right =
              translateX(boundingBox.right, rotation, size, absoluteImageSize);
          bottom =
              translateY(boundingBox.bottom, rotation, size, absoluteImageSize);

          // Draw a bounding rectangle around the barcode
          canvas.drawCircle(Offset(left, top), 3.0, paint);
          // canvas.drawRect(
          //   Rect.fromLTRB(left, top, right, bottom),
          //   paint,
          // );
        }
      } else {
        final List<Offset> offsetPoints = <Offset>[];
        for (final point in cornerPoints) {
          final double x =
              translateX(point.x.toDouble(), rotation, size, absoluteImageSize);
          final double y =
              translateY(point.y.toDouble(), rotation, size, absoluteImageSize);

          offsetPoints.add(Offset(x, y));

          // Due to possible rotations we need to find the smallest and largest
          top = min(top, y);
          bottom = max(bottom, y);
          left = min(left, x);
          right = max(right, x);
        }
        // Add the first point to close the polygon
        canvas.drawCircle(
            Offset(left + (right - left) / 2, top + (bottom - top) / 2),
            20.0,
            paint);

        //draw arrow
        canvas.drawLine(
            Offset(left + (right - left) / 2 - 10, top + (bottom - top) / 2),
            Offset(left + (right - left) / 2 + 10, top + (bottom - top) / 2),
            paintWhite);
        canvas.drawLine(
            Offset(left + (right - left) / 2, top + (bottom - top) / 2 - 10),
            Offset(left + (right - left) / 2 + 10, top + (bottom - top) / 2),
            paintWhite);
        canvas.drawLine(
            Offset(left + (right - left) / 2, top + (bottom - top) / 2 + 10),
            Offset(left + (right - left) / 2 + 10, top + (bottom - top) / 2),
            paintWhite);
      }

      _barcodesOnScreen.add({
        Rect.fromLTRB(left, top, right, bottom): barcode,
      });

      canvas.drawParagraph(
        builder.build()
          ..layout(ParagraphConstraints(
            width: right - left,
          )),
        Offset(left, top),
      );
    }
  }

  @override
  bool shouldRepaint(MultiQrcodeSelectPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.barcodes != barcodes;
  }

  @override
  bool? hitTest(Offset position) {
    // print("@@@ hitTest $position");
    for (var a in _barcodesOnScreen) {
      for (var b in a.keys) {
        if (b.contains(position)) {
          // print("@@@ ${b}");
          // print("@@@ ${a[b]!.rawValue}");
          onSelect(a[b]!);
          return false;
        }
      }
    }

    return false;
  }
}
