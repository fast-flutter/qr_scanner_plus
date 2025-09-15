import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../events.dart';
import './focuspoint.dart';

class CameraView extends StatefulWidget {
  CameraView(
      {Key? key,
      required this.customPaint,
      required this.onImage,
      this.onCameraFeedReady,
      this.onDetectorViewModeChanged,
      this.onCameraLensDirectionChanged,
      this.initialCameraLensDirection = CameraLensDirection.back})
      : super(key: key);

  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final VoidCallback? onCameraFeedReady;
  final VoidCallback? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  setCameraFocusPoint(Offset offset) {
    eventBus.fire(SetFocusPointEvent(offset));
  }

  resetCameraFocusPoint() {
    eventBus.fire(ReSetFocusPointEvent());
  }

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = -1;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  double zoomTarget = 0;
  double _lastGestureScale = 1;
  FocusPoint? focusPoint;
  bool paused = false;
  double zoomLevel = 1, minZoomLevel = 1, maxZoomLevel = 1;

  @override
  void initState() {
    super.initState();

    if (mounted) {
      _initialize();

      _handleCameraZoomChange();

      eventBus.on<PausePreviewEvent>().listen((e) async {
        if (mounted && _controller?.value.isInitialized == true) {
          paused = true;
          _controller?.pausePreview();
          focusPoint?.hide();
        }
      });

      eventBus.on<ResumePreviewEvent>().listen((e) async {
        if (mounted && _controller?.value.isInitialized == true) {
          paused = false;
          _controller?.resumePreview();
          focusPoint?.show();
        }
      });

      // Listen to background/resume changes
      WidgetsBinding.instance.addObserver(this);
    }
  }

  Future<bool> requestPermission() async {
    PermissionStatus status = await Permission.camera.request();

    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited) {
      return Future.value(true);
    } else {
      print("@@@ QrScannerCameraPlusView.requestPermission(): ${status}");
      return Future.value(false);
    }
  }

  Future _initialize() async {
    return requestPermission().then((isGranted) async {
      if (isGranted == true) {
        if (_cameras.isEmpty) {
          _cameras = await availableCameras();
        }
        for (var i = 0; i < _cameras.length; i++) {
          if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
            _cameraIndex = i;
            break;
          }
        }
        if (_cameraIndex != -1) {
          _startLiveFeed();
        }
      }
    });
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  void setZoomLevel(double zoomLevel) {
    if (mounted && _controller?.value.isInitialized == true) {
      print("@@@ setZoomLevel to $zoomLevel");
      _controller?.setZoomLevel(zoomLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          _liveFeedBody(),
          focusPoint ?? const SizedBox.shrink()
        ]));
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) return Container();
    if (_controller == null) return Container();
    if (_controller?.value.isInitialized == false) return Container();

    final size = MediaQuery.of(context).size;

    return GestureDetector(
        child: Container(
            width: size.width,
            height: size.height,
            child: FittedBox(
                fit: BoxFit.cover,
                child: Container(
                  width: size.width, // the actual width is not important here
                  child: CameraPreview(
                    _controller!,
                    child: widget.customPaint,
                  ),
                ))),
        onScaleUpdate: (ScaleUpdateDetails details) {
          double scale = details.scale;

          if (scale - _lastGestureScale > 0.005) {
            zoomTarget = 0.3;
          } else if (_lastGestureScale - scale > 0.005) {
            zoomTarget = -0.3;
          } else {
            zoomTarget = 0;
          }
          _lastGestureScale = scale;
        },
        onScaleEnd: (ScaleEndDetails details) {
          zoomTarget = 0;
          _lastGestureScale = 1;
        },
        onTapUp: (TapUpDetails details) {
          final size = MediaQuery.of(context).size;

          var offset = Offset(details.localPosition.dx / size.width,
              details.localPosition.dy / size.height);

          focusPoint?.setCameraFocusPoint(offset);
        });
  }

  Widget _backButton() => Positioned(
        top: 40,
        left: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: () => Navigator.of(context).pop(),
            backgroundColor: Colors.black54,
            child: Icon(
              Icons.arrow_back_ios_outlined,
              size: 20,
            ),
          ),
        ),
      );

  Widget _detectionViewModeToggle() => Positioned(
        bottom: 8,
        left: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: widget.onDetectorViewModeChanged,
            backgroundColor: Colors.black54,
            child: Icon(
              Icons.photo_library_outlined,
              size: 25,
            ),
          ),
        ),
      );

  Widget _exposureControl() => Positioned(
        top: 40,
        right: 8,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 250,
          ),
          child: Column(children: [
            Container(
              width: 55,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    '${_currentExposureOffset.toStringAsFixed(1)}x',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SizedBox(
                  height: 30,
                  child: Slider(
                    value: _currentExposureOffset,
                    min: _minAvailableExposureOffset,
                    max: _maxAvailableExposureOffset,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                    onChanged: (value) async {
                      setState(() {
                        _currentExposureOffset = value;
                      });
                      await _controller?.setExposureOffset(value);
                    },
                  ),
                ),
              ),
            )
          ]),
        ),
      );

  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      _currentExposureOffset = 0.0;
      _controller?.getMinExposureOffset().then((value) {
        _minAvailableExposureOffset = value;
      });
      _controller?.getMaxExposureOffset().then((value) {
        _maxAvailableExposureOffset = value;
      });
      _controller?.startImageStream(_processCameraImage).then((value) {
        if (widget.onCameraFeedReady != null) {
          widget.onCameraFeedReady!();
        }
        if (widget.onCameraLensDirectionChanged != null) {
          widget.onCameraLensDirectionChanged!(camera.lensDirection);
        }
      });

      focusPoint = FocusPoint(_controller!);
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
  }

  void _handleCameraZoomChange() {
    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (mounted) {
        if (zoomTarget != 0) {
          zoomLevel = zoomLevel + zoomTarget;

          if (zoomLevel < minZoomLevel) {
            zoomLevel = minZoomLevel;
          } else if (zoomLevel > min(maxZoomLevel, 3)) {
            zoomLevel = min(maxZoomLevel, 3);
          }

          zoomTarget = 0;
          setZoomLevel(zoomLevel);
        }
      }
    });
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    print("@@@ didChangeAppLifecycleState {$state}");

    if (_controller?.value.isInitialized == true) {
      if (state == AppLifecycleState.resumed) {
        if (_controller?.value.isInitialized ?? false == false) {
          _initialize();
        } else {
          _controller?.resumePreview();
        }
      } else if (state == AppLifecycleState.paused) {
        _controller?.pausePreview();
      }
    }
  }
}
