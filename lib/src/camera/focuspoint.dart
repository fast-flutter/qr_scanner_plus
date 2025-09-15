import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../events.dart';

class FocusPoint extends StatefulWidget {
  CameraController cameraController;
  FocusPoint(this.cameraController, {Key? key}) : super(key: key);
  bool _hide = false;

  resetFocusPoint() {
    if (cameraController.value.isInitialized == true) {
      eventBus.fire(ReSetFocusPointEvent());
    }
  }

  setCameraFocusPoint(Offset offset) {
    eventBus.fire(SetFocusPointEvent(offset));
  }

  hide() {
    _hide = true;
  }

  show() {
    _hide = false;
  }

  @override
  State<FocusPoint> createState() => _FocusPointState();
}

class _FocusPointState extends State<FocusPoint> {
  Offset _lastFocusPoint = Offset.zero;
  double _focusPointAnimationOpacity = 0.0;
  AccelerometerEvent? _lastAccelerometerEvent;
  bool _needAutoResetFocusPoint = false;
  bool _busy = false;
  bool _busy_reset = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _lastFocusPoint.dx - 32,
      top: _lastFocusPoint.dy - 32,
      child: widget._hide
          ? const SizedBox.shrink()
          : IgnorePointer(
              child: AnimatedOpacity(
                  opacity: _focusPointAnimationOpacity,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.linear,
                  child: const Image(
                      image: AssetImage('assets/images/focus.png',
                          package: 'qr_scanner_plus'),
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain))),
    );
  }

  @override
  void initState() {
    super.initState();
    _listenFocusPointEvent();
    _autoResetFocusModeByAccelerometer();
  }

  _listenFocusPointEvent() {
    eventBus.on<SetFocusPointEvent>().listen((e) async {
      if (!mounted) return;

      if (_busy == true) {
        return;
      }
      _busy = true;

      Offset offset = e.offset;

      final size = MediaQuery.of(context).size;

      _lastFocusPoint = Offset(offset.dx * size.width, offset.dy * size.height);

      //cool down time
      Future.delayed((const Duration(milliseconds: 200)), () {
        setState(() {
          _busy = false;
        });
      });

      _setFocusPoint(offset);
    });

    eventBus.on<ReSetFocusPointEvent>().listen((e) async {
      if (!mounted) return;
      _resetFocusPoint();
    });
  }

  _setFocusPoint(Offset? point) async {
    if (widget.cameraController.value.isInitialized == true) {
      await widget.cameraController.setFocusMode(FocusMode.locked);

      print("@@@ setFocusPoint: ${point}");

      widget.cameraController.setFocusPoint(point);

      _needAutoResetFocusPoint = false;
      Future.delayed(const Duration(milliseconds: 5000), () {
        _needAutoResetFocusPoint = true;
      });

      _playAnimation();
    }
  }

  _resetFocusPoint() async {
    if (!mounted) return;

    if (_busy_reset == true) {
      return;
    }
    _busy_reset = true;

    //cool down time
    Future.delayed((const Duration(milliseconds: 1000)), () {
      setState(() {
        _busy_reset = false;
      });
    });

    if (widget.cameraController.value.isInitialized == true) {
      print("@@@ resetFocusPoint");
      widget.cameraController.setFocusMode(FocusMode.auto);
    }
  }

  _playAnimation({int loop = 3}) async {
    for (var i = 0; i < loop; i++) {
      await Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _focusPointAnimationOpacity = 0.5;
          });
        }
      });
      await Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _focusPointAnimationOpacity = 0.8;
          });
        }
      });
    }

    if (mounted) {
      setState(() {
        _focusPointAnimationOpacity = 0;
      });
    }
  }

  _autoResetFocusModeByAccelerometer() {
    if (widget.cameraController.value.isInitialized == true) {
      //If the user has moved the phone (calc by accelerometer values), switch back to auto-focus.

      accelerometerEvents.listen((AccelerometerEvent event) {
        if (_lastAccelerometerEvent != null) {
          var diff = (event.x * event.y * event.z -
                  _lastAccelerometerEvent!.x *
                      _lastAccelerometerEvent!.y *
                      _lastAccelerometerEvent!.z) *
              100 ~/
              100;

          if (_needAutoResetFocusPoint == true && diff.abs() > 10) {
            _resetFocusPoint();
            _needAutoResetFocusPoint = false;
          }
        }

        _lastAccelerometerEvent = event;
      });
    }
  }
}
