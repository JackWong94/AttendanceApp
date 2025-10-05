import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/web_face_api.dart' as webFaceApi;

/// Callback when the capture sequence finishes
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
    "Slightly turn your head to the LEFT",
    "Slightly turn your head to the RIGHT",
  ];

  Future<void> _captureStep() async {
    if (_isCapturing || !widget.cameraService.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      final picture = await widget.cameraService.controller!.takePicture();
      final bytes = await picture.readAsBytes();

      final img = await webFaceApi.uint8ListToImage(bytes);
      final resizedImg = await webFaceApi.resizeImage(img, 160, 160);
      final descriptor = await webFaceApi.computeFaceDescriptorSafe(resizedImg);

      if (descriptor.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No face detected in step ${_currentStep + 1}")),
        );
      } else {
        _capturedPhotos.add(bytes);
        _capturedEmbeddings.add(descriptor);
        _currentStep++;
      }

      // If all steps captured, call the callback
      if (_currentStep >= steps.length) {
        widget.onCompleted(_capturedPhotos, _capturedEmbeddings);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error capturing photo: $e")),
      );
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void _resetCapture() {
    setState(() {
      _capturedPhotos.clear();
      _capturedEmbeddings.clear();
      _currentStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Camera preview on top
        SizedBox(
          height: 250,
          child: widget.cameraService.controller != null &&
              widget.cameraService.controller!.value.isInitialized
              ? CameraPreview(widget.cameraService.controller!)
              : const Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 12),
        // Current step instruction
        if (_currentStep < steps.length)
          Text(
            "Step ${_currentStep + 1}/${steps.length}: ${steps[_currentStep]}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 12),
        // Capture / Retake button
        ElevatedButton.icon(
          onPressed: _isCapturing
              ? null
              : (_currentStep < steps.length ? _captureStep : _resetCapture),
          icon: const Icon(Icons.videocam),
          label: Text(
            _currentStep < steps.length
                ? "Capture Image ${_currentStep + 1}/${steps.length}"
                : "Retake",
          ),
        ),
        // Preview of captured photos
        if (_capturedPhotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Wrap(
              spacing: 4,
              children: _capturedPhotos
                  .map((bytes) => Image.memory(bytes,
                  width: 80, height: 80, fit: BoxFit.cover))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
