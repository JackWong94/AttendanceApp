// lib/widgets/face_capture_widget.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_capturing_service.dart';

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
  final List<Uint8List> _photos = [];
  final List<List<double>> _embeddings = [];
  int _step = 0;
  bool _isCapturing = false;

  final _steps = [
    "Look straight ahead",
    "Turn slightly to the LEFT",
    "Turn slightly to the RIGHT",
  ];

  late final FaceCaptureService _faceCaptureService =
  FaceCaptureService(widget.cameraService);

  Future<void> _capture() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final result = await _faceCaptureService.captureFace(_step);
      if (result == null) return;

      _photos.add(result.photo);
      _embeddings.add(result.embedding);

      if (_step + 1 >= _steps.length) {
        widget.onCompleted(_photos, _embeddings);
      } else {
        setState(() => _step++);
        _showMsg("Good! Now ${_steps[_step]}");
      }
    } catch (e) {
      _showMsg(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _reset() {
    setState(() {
      _photos.clear();
      _embeddings.clear();
      _step = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allDone = _photos.length >= _steps.length;

    return Column(
      children: [
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

              // Circle overlay
              IgnorePointer(
                child: Container(
                  width: 225,
                  height: 225,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                ),
              ),
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

        Text(
          allDone
              ? "✅ All steps captured!"
              : "Step ${_step + 1}/${_steps.length}: ${_steps[_step]}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: _isCapturing
              ? null
              : (allDone ? _reset : _capture),
          icon: Icon(allDone ? Icons.refresh : Icons.camera_alt),
          label: Text(allDone ? "Retake Photos" : "Capture"),
        ),

        if (_photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 4,
              children: _photos
                  .map((bytes) => Image.memory(bytes, width: 80, height: 80))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
