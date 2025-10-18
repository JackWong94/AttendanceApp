import 'dart:typed_data';
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

  Future<void> _captureStep() async {
    if (_isCapturing || !widget.cameraService.isInitialized) return;
    setState(() => _isCapturing = true);

    try {
      final controller = widget.cameraService.controller!;
      final picture = await controller.takePicture();
      final bytes = await picture.readAsBytes();

      // Convert image and detect face + landmarks
      final img = await webFaceApi.WebFaceApi.uint8ListToImage(bytes);
      final resizedImg = await webFaceApi.WebFaceApi.resizeImage(img, 160, 160);
      final faceData = await webFaceApi.WebFaceApi.detectFaceWithBox(resizedImg);

      if (faceData == null || faceData['descriptor'] == null) {
        _showMsg("No face detected in step ${_currentStep + 1}");
        return;
      }

      // 1️⃣ Face size check
      final box = faceData['box'];
      final faceRatio = (box['width'] * box['height']) / (160 * 160);
      if (faceRatio < 0.15) {
        _showMsg("Move closer to the camera.");
        return;
      }

      // 2️⃣ Head direction check (nose alignment)
      final nose = faceData['landmarks']['nose'];
      final leftEye = faceData['landmarks']['leftEye'];
      final rightEye = faceData['landmarks']['rightEye'];
      final midX = (leftEye['x'] + rightEye['x']) / 2;
      final offset = nose['x'] - midX;

      if (_currentStep == 0 && offset.abs() > 10) {
        _showMsg("Face should look straight ahead.");
        return;
      }
      if (_currentStep == 1 && offset > -5) {
        _showMsg("Turn slightly more LEFT.");
        return;
      }
      if (_currentStep == 2 && offset < 5) {
        _showMsg("Turn slightly more RIGHT.");
        return;
      }

      // ✅ Passed all checks → store this step’s photo and embedding
      _capturedPhotos.add(bytes);
      _capturedEmbeddings.add(List<double>.from(faceData['descriptor']));

      // ✅ Proceed to next step or complete
      if (_currentStep + 1 >= steps.length) {
        widget.onCompleted(_capturedPhotos, _capturedEmbeddings);
        setState(() {}); // refresh button state
      } else {
        setState(() {
          _currentStep++;
        });
        _showMsg("Good! Now ${steps[_currentStep]}");
      }
    } catch (e) {
      _showMsg("Error capturing photo: $e");
      debug.log("Error capturing photo: $e");
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
          "Are you sure you want to retake all photos?\n"
              "This will discard your current captures.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
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
        // Camera preview + face guide
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

              IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                    color: Colors.transparent,
                  ),
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
          onPressed: _isCapturing
              ? null
              : (isAllCaptured ? _confirmRetake : _captureStep),
          icon: Icon(isAllCaptured ? Icons.refresh : Icons.camera),
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
