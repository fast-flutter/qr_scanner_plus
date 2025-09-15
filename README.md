# qr_scanner_plus

A better qrcode and barcode scanner.

Features:
- ✅ Offline use (using Google MLKit).
- ✅ Camera view can click to set focus point.
- ✅ Camera view can use scale gesture.
- ✅ Multi qrcode/barcode supported.
- ✅ Easy to use.
- ✅  Automatically find potential QR codes and automatically zoom in and focus.

## Getting Started

### iOS 

Support for iOS > 15.5
1. Please add as follows in **info.plist**

```xml
<key>NSCameraUsageDescription</key>
<string>To take photos and video with your camera</string>
<key>NSMicrophoneUsageDescription</key>
<string>To take video with your camera</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>To access your photos in your Library</string>
```

2. and add to **Podfile**
   
```ruby


$iOSVersion= "15.5"

post_install do |installer|

  # add these lines:
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["EXCLUDED_ARCHS[sdk=*]"] = "armv7"
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
  end

  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)


    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'

      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
         '$(inherited)',

        # Disable firebase-hosted ML models
         'MLKIT_FIREBASE_MODELS=0',

         ## dart: PermissionGroup.camera
         'PERMISSION_CAMERA=1',

         ## dart: PermissionGroup.microphone
         'PERMISSION_MICROPHONE=1',

         ## dart: PermissionGroup.photos
         'PERMISSION_PHOTOS=1',

         ## dart: [PermissionGroup.location, PermissionGroup.locationAlways, PermissionGroup.locationWhenInUse]
         'PERMISSION_LOCATION=1',

       ]
    end
  end
```
### Android
minSdkVersion: 21
targetSdkVersion: 35

Add to **AndroidManifest.xml**

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```


## Example 

```dart
import 'package:flutter/material.dart';
import 'package:qr_scanner_plus/qr_scanner_plus.dart';

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
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('BarcodeScannerPlus example'),
        ),
        body: Center(
            child: QrScannerPlusView(
          _onResult,
          debug: true,
        )),
      ),
    );
  }

  _onResult(List<Barcode> barcodes) {
    for (final barcode in barcodes) {
      print(barcode.type);
      print(barcode.rawValue);
    }
  }
}

```

## Screenshot
![](https://github.com/fast-flutter/qr_scanner_plus/raw/master/assets/screenshot/1.jpg)