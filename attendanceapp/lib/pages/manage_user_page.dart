import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:attendanceapp/services/image_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/face_model_service.dart';

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  final _userService = UserModelService.instance;
  final _imageService = ImageModelService.instance;

  bool _loading = false;
  Uint8List? _frontPhoto;
  Uint8List? _leftPhoto;
  Uint8List? _rightPhoto;
  String _employeeId = "EMP001"; // example

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void dispose() {
    _imageService.clearCache(); // ✅ clear when leaving
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() => _loading = true);
    try {
      final photos = await _imageService.loadUserPhotos(_employeeId);
      setState(() {
        _frontPhoto = photos['front'];
        _leftPhoto = photos['left'];
        _rightPhoto = photos['right'];
      });
    } catch (e) {
      debugPrint("❌ Failed to load user photos: $e");
    } finally {
      _imageService.traceMemory();
      setState(() => _loading = false);
    }
  }

  Future<void> _recapturePhotos(Map<String, Uint8List> newPhotos) async {
    setState(() => _loading = true);
    try {
      await _imageService.saveCapturedPhotos(
        employeeId: _employeeId,
        photos: newPhotos.values.toList(),
      );
      await FaceModelService.reload();
      await _loadPhotos(); // refresh UI
    } catch (e) {
      debugPrint("❌ Failed to recapture: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage User Photos")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_frontPhoto != null)
            Image.memory(_frontPhoto!, width: 120, height: 120),
          if (_leftPhoto != null)
            Image.memory(_leftPhoto!, width: 120, height: 120),
          if (_rightPhoto != null)
            Image.memory(_rightPhoto!, width: 120, height: 120),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _recapturePhotos({
              "front": _frontPhoto!,
              "left": _leftPhoto!,
              "right": _rightPhoto!,
            }),
            child: const Text("Re-capture"),
          ),
        ],
      ),
    );
  }
}
