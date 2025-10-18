import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "face_capture_widget", enable: true);

typedef FaceCaptureCallback = void Function(
    List<Uint8List> photos, List<List<double>> embeddings);

class FaceCaptureWidget extends StatefulWidget {
  const FaceCaptureWidget({
    super.key,
    required this.cameraService,
    required this.onCompleted,
  });

  final CameraService cameraService;
  final FaceCaptureCallback onCompleted;

  @override
  State<FaceCaptureWidget> createState() => _FaceCaptureWidgetState();
}

class _FaceCaptureWidgetState extends State<FaceCaptureWidget> {
  List<Uint8List> _capturedPhotos = [];
  List<List<double>> _capturedEmbeddings = [];
  int _currentStep = 0;
  bool _isCapturing = false;

  final List<String> steps = [
    "Look straight ahead",
    "Turn slightly to the LEFT",
    "Turn slightly to the RIGHT",
  ];

  // --- Face detection coordinate space (from WebFaceApi)
  static const double _resizedSize = 160.0;
  static const double _circleCenter = _resizedSize / 2.0; // 80.0
  static const double _circleRadius = _resizedSize / 2.0; // 80.0 (used for logic)

  // --- UI overlay size
  static const double _previewCirclePx = 225.0; // UI circle diameter
  static final double _scaleFactor = _previewCirclePx / _resizedSize; // ~1.375

  Future<void> _captureStep() async {
    if (_isCapturing || !widget.cameraService.isInitialized) return;
    setState(() => _isCapturing = true);

    try {
      final controller = widget.cameraService.controller!;
      final picture = await controller.takePicture();
      final bytes = await picture.readAsBytes();

      // Convert to HTML image for face-api.js
      final img = await webFaceApi.WebFaceApi.uint8ListToImage(bytes);
      final resizedImg = await webFaceApi.WebFaceApi.resizeImage(
        img,
        _resizedSize.toInt(),
        _resizedSize.toInt(),
      );
      final faceData = await webFaceApi.WebFaceApi.detectFaceWithBox(resizedImg);

      if (faceData == null || faceData['descriptor'] == null) {
        _showMsg("No face detected in step ${_currentStep + 1}");
        return;
      }

      // --- Face bounding box (in 160x160 detection space)
      final box = faceData['box'];
      final double faceCenterX =
          (box['x'] ?? 0).toDouble() + (box['width'] ?? 0).toDouble() / 2.0;
      final double faceCenterY =
          (box['y'] ?? 0).toDouble() + (box['height'] ?? 0).toDouble() / 2.0;
      final double faceRadius =
          ((box['width'] ?? 0).toDouble() + (box['height'] ?? 0).toDouble()) /
              4.0;

      // --- Position check ---
      final double dx = faceCenterX - _circleCenter;
      final double dy = faceCenterY - _circleCenter;
      final double distanceFromCenter = math.sqrt(dx * dx + dy * dy);

      // Centered if within 25% of detection circle radius
      final double centerThreshold = _circleRadius * 0.25;
      if (distanceFromCenter > centerThreshold) {
        _showMsg("Center your face inside the circle.");
        return;
      }

      // --- Face size check ---
      debug.log("Face radius: $faceRadius");
      debug.log("Circle radius: $_circleRadius");
      if (faceRadius < _circleRadius * 0.5) {
        _showMsg("Move closer to the camera.");
        return;
      }
      if (faceRadius > _circleRadius * 0.60) {
        _showMsg("Move slightly back.");
        return;
      }

      // --- Head direction (yaw) check ---
      final landmarks = faceData['landmarks'];
      if (landmarks == null ||
          landmarks['nose'] == null ||
          landmarks['leftEye'] == null ||
          landmarks['rightEye'] == null) {
        _showMsg("Face landmarks not detected. Try again.");
        return;
      }

      final nose = landmarks['nose'];
      final leftEye = landmarks['leftEye'];
      final rightEye = landmarks['rightEye'];
      final midX = (leftEye['x'] + rightEye['x']) / 2.0;
      final offset = (nose['x'] - midX);

      if (_currentStep == 0 && offset.abs() > 1.5) {
        _showMsg("Face should look straight ahead.");
        return;
      }
      if (_currentStep == 1 && offset > -2.5) {
        _showMsg("Turn slightly more LEFT.");
        return;
      }
      if (_currentStep == 2 && offset < 2.5) {
        _showMsg("Turn slightly more RIGHT.");
        return;
      }

      // --- Passed all checks ---
      _capturedPhotos.add(bytes);
      _capturedEmbeddings.add(List<double>.from(faceData['descriptor']));

      if (_currentStep + 1 >= steps.length) {
        widget.onCompleted(_capturedPhotos, _capturedEmbeddings);
        setState(() {}); // refresh UI
      } else {
        setState(() {
          _currentStep++;
        });
        _showMsg("Good! Now ${steps[_currentStep]}");
      }
    } catch (e, st) {
      _showMsg("Error capturing photo: $e");
      debug.log("Error capturing photo: $e\n$st");
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _confirmRetake() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Retake Photos?"),
        content: const Text(
          "Are you sure you want to retake all photos?\nThis will discard your current captures.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes, Retake"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _resetCapture();
      _showMsg("Please start capturing again.");
    }
  }

  void _resetCapture() {
    setState(() {
      _capturedPhotos.clear();
      _capturedEmbeddings.clear();
      _currentStep = 0;
    });
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final isAllCaptured = _capturedPhotos.length >= steps.length;

    return Column(
      children: [
        // Camera preview + overlay
        SizedBox(
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.cameraService.controller != null &&
                  widget.cameraService.controller!.value.isInitialized)
                CameraPreview(widget.cameraService.controller!)
              else
                const Center(child: CircularProgressIndicator()),

              // --- Circle overlay (scaled correctly to detection space) ---
              IgnorePointer(
                child: Container(
                  width: _circleRadius * 2 * _scaleFactor,
                  height: _circleRadius * 2 * _scaleFactor,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                    color: Colors.transparent,
                  ),
                ),
              ),

              // Optional: visualize face box (for debugging)
              // if (kDebugMode && _lastFaceBox != null)
              //   Positioned(
              //     left: _lastFaceBox!['x'] * _scaleFactor,
              //     top: _lastFaceBox!['y'] * _scaleFactor,
              //     child: Container(
              //       width: _lastFaceBox!['width'] * _scaleFactor,
              //       height: _lastFaceBox!['height'] * _scaleFactor,
              //       decoration: BoxDecoration(
              //         border: Border.all(color: Colors.greenAccent, width: 1),
              //       ),
              //     ),
              //   ),

              const Positioned(
                bottom: 12,
                child: Text(
                  "Align your face within the circle",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (!isAllCaptured)
          Text(
            "Step ${_currentStep + 1}/${steps.length}: ${steps[_currentStep]}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          )
        else
          const Text(
            "✅ All steps captured!",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),

        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed:
          _isCapturing ? null : (isAllCaptured ? _confirmRetake : _captureStep),
          icon: Icon(isAllCaptured ? Icons.refresh : Icons.camera_alt),
          label: Text(isAllCaptured
              ? "Retake Photos"
              : "Capture ${_currentStep + 1}/${steps.length}"),
        ),

        if (_capturedPhotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 4,
              children: _capturedPhotos
                  .map((bytes) => Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
