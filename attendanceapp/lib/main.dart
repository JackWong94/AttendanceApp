import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'pages/camera_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  CameraDescription? frontCamera;

  // Only attempt to get cameras on Android or iOS
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
    final cameras = await availableCameras();
    frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  runApp(MyApp(camera: frontCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription? camera;

  const MyApp({super.key, this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Demo',
      home: CameraPage(camera: camera),
    );
  }
}
