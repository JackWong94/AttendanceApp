import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:async';
import 'package:attendanceapp/configs_and_tools/debug.dart';
import 'dart:math' as math;

class WebFaceApi {
  static Debug debug = Debug(module: "web_face_api", enable: true);

  static const String _cacheVersion = "v2"; // increment when models change
  static dynamic _db;
  static const String _dbName = "FaceApiCacheDB";
  static const String _descriptorStore = "descriptors";

  /// Initialize IndexedDB safely
  static Future<void> _initDB() async {
    if (_db != null) return;

    try {
      final request = html.window.indexedDB!.open(_dbName, version: 1,
          onUpgradeNeeded: (e) {
            final db =
            js_util.getProperty(js_util.getProperty(e, 'target'), 'result');
            if (!js_util.callMethod(
                js_util.getProperty(db, 'objectStoreNames'), 'contains', [_descriptorStore])) {
              js_util.callMethod(db, 'createObjectStore', [_descriptorStore]);
            }
          });

      _db = await request;
      debug.log("IndexedDB initialized");
    } catch (e) {
      debug.log("⚠️ IndexedDB initialization failed: $e");
      _db = null; // fallback to online mode
    }
  }

  /// Check cache version
  static Future<void> _checkCacheVersion() async {
    try {
      await _initDB();
      if (_db == null) return; // skip version check if no DB

      final txn = _db.transaction(_descriptorStore, 'readonly');
      final store = txn.objectStore(_descriptorStore);
      final result = await store.getObject('cacheVersion');

      if (result == null) {
        final txn2 = _db.transaction(_descriptorStore, 'readwrite');
        txn2.objectStore(_descriptorStore).put(_cacheVersion, 'cacheVersion');
        await txn2.completed;
        debug.log("Initial cache version stored as $_cacheVersion");
        return;
      }

      if (result != _cacheVersion) {
        debug.log("Cache version changed. Clearing old cache...");
        final txn3 =
        js_util.callMethod(_db, 'transaction', [_descriptorStore, 'readwrite']);
        final store3 = js_util.callMethod(txn3, 'objectStore', [_descriptorStore]);
        js_util.callMethod(store3, 'clear', []);
        await js_util.promiseToFuture(
            js_util.getProperty(txn3, 'done') ?? js_util.getProperty(txn3, 'completed'));
        final txn4 = _db.transaction(_descriptorStore, 'readwrite');
        txn4.objectStore(_descriptorStore).put(_cacheVersion, 'cacheVersion');
        await txn4.completed;
        debug.log("Cache version updated to $_cacheVersion");
      }
    } catch (e) {
      debug.log("⚠️ Cache version check failed: $e");
    }
  }

  /// Determine model path
  static String getModelPath({String modelsFolder = "models"}) {
    final path = html.window.location.pathname ?? "/";
    final normalizedPath = path.endsWith("/") ? path : "$path/";
    if (normalizedPath.endsWith("$modelsFolder/")) return normalizedPath;
    return "$normalizedPath$modelsFolder/";
  }

  /// Load models from network
  static Future<void> loadModels({int retries = 20, int delayMs = 50}) async {
    await _checkCacheVersion();

    debug.timeStart("loadModels");

    for (var i = 0; i < retries; i++) {
      if (js_util.hasProperty(html.window, 'faceapi')) break;
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (!js_util.hasProperty(html.window, 'faceapi')) {
      throw Exception("Face-api.js not loaded!");
    }

    final faceapi = js_util.getProperty(html.window, 'faceapi');
    final nets = js_util.getProperty(faceapi, 'nets');
    final modelNames = [
      'ssdMobilenetv1',
      'faceLandmark68Net',
      'faceRecognitionNet',
      'tinyFaceDetector'
    ];
    final modelPath = getModelPath();

    for (final netName in modelNames) {
      await js_util.promiseToFuture(js_util.callMethod(
          js_util.getProperty(nets, netName), 'loadFromUri', [modelPath]));
      debug.log("$netName loaded from $modelPath");
    }

    debug.timeEnd("loadModels");
  }

  /// Convert Uint8List to ImageElement
  static Future<html.ImageElement> uint8ListToImage(Uint8List bytes) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement(src: url);
    await js_util.promiseToFuture(js_util.callMethod(img, 'decode', []));
    html.Url.revokeObjectUrl(url);
    return img;
  }

  /// Resize image
  static Future<html.ImageElement> resizeImage(
      html.ImageElement img, int width, int height) async {
    final canvas = html.CanvasElement(width: width, height: height);
    canvas.context2D.drawImageScaled(img, 0, 0, width, height);
    final resizedImg = html.ImageElement(src: canvas.toDataUrl());
    await js_util.promiseToFuture(js_util.callMethod(resizedImg, 'decode', []));
    return resizedImg;
  }

  /// Compute face descriptor (no cache)
  static Future<List<double>> computeFaceDescriptorSafe(
      html.ImageElement img, {String? debugKey}) async {
    await _checkCacheVersion();

    debug.log("Computing descriptor for ${debugKey ?? 'unknown'}...");
    debug.timeStart("computeFaceDescriptor");

    final faceapi = js_util.getProperty(html.window, 'faceapi');
    if (faceapi == null) throw Exception("Face-api.js not loaded");

    final options = js_util.callConstructor(
      js_util.getProperty(faceapi, 'TinyFaceDetectorOptions'),
      [js_util.jsify({'inputSize': 160, 'scoreThreshold': 0.1})],
    );

    final detectionWithDescriptor = await js_util.promiseToFuture(
      js_util.callMethod(
        js_util.callMethod(
          js_util.callMethod(faceapi, 'detectSingleFace', [img, options]),
          'withFaceLandmarks',
          [],
        ),
        'withFaceDescriptor',
        [],
      ),
    );

    if (detectionWithDescriptor == null) {
      throw Exception("No face descriptor detected");
    }

    final descriptorJs = js_util.getProperty(detectionWithDescriptor, 'descriptor');

    List<double> descriptor = [];

    if (descriptorJs != null) {
      // Handle both JS Array and Float32Array
      if (descriptorJs is List) {
        descriptor = descriptorJs.map((e) {
          final val = e;
          if (val is num) return val.toDouble();
          return 0.0;
        }).toList();
      } else if (js_util.hasProperty(descriptorJs, 'length')) {
        // Convert from Float32Array to Dart List<double>
        final length = js_util.getProperty(descriptorJs, 'length') as int;
        descriptor = List.generate(length, (i) {
          final val = js_util.getProperty(descriptorJs, i);
          return (val is num) ? val.toDouble() : 0.0;
        });
      } else {
        print('⚠️ descriptorJs is not a List or Float32Array: $descriptorJs');
      }
    } else {
      print('⚠️ descriptorJs is null for this face');
    }

    debug.timeEnd("computeFaceDescriptor");
    debug.log("Descriptor computed successfully for ${debugKey ?? 'unknown'}");

    return descriptor;
  }

  /// Detect a face and return bounding box info (and landmarks if available)
  /// Detect a face and return bounding box info (and landmarks if available)
  static Future<Map<String, dynamic>?> detectFaceWithBox(html.ImageElement img) async {
    try {
      final faceapi = js_util.getProperty(html.window, 'faceapi');
      if (faceapi == null) throw Exception("❌ face-api.js not loaded");

      final TinyFaceDetectorOptions = js_util.getProperty(faceapi, 'TinyFaceDetectorOptions');
      if (TinyFaceDetectorOptions == null) throw Exception("❌ TinyFaceDetectorOptions not found");

      final options = js_util.callConstructor(
        TinyFaceDetectorOptions,
        [js_util.jsify({'inputSize': 160, 'scoreThreshold': 0.1})],
      );

      // Run face detection chain
      final detectionPromise = js_util.callMethod(faceapi, 'detectSingleFace', [img, options]);
      final withLandmarks = js_util.callMethod(detectionPromise, 'withFaceLandmarks', []);
      final withDescriptor = js_util.callMethod(withLandmarks, 'withFaceDescriptor', []);
      final detectionWithDescriptor = await js_util.promiseToFuture(withDescriptor);

      if (detectionWithDescriptor == null) {
        print('⚠️ No face detected');
        return null;
      }

      // Extract detection safely
      final detection = js_util.getProperty(detectionWithDescriptor, 'detection');
      final boxObj = js_util.getProperty(detection, 'box');
      if (boxObj == null) {
        print('⚠️ Bounding box missing');
        return null;
      }

      final x = (js_util.getProperty(boxObj, 'x') ?? 0).toDouble();
      final y = (js_util.getProperty(boxObj, 'y') ?? 0).toDouble();
      final width = (js_util.getProperty(boxObj, 'width') ?? 0).toDouble();
      final height = (js_util.getProperty(boxObj, 'height') ?? 0).toDouble();
      final score = (js_util.getProperty(detection, 'score') ?? 0.0).toDouble();

      // 🧠 Extract landmarks correctly using getNose(), getLeftEye(), getRightEye()
      final landmarksObj = js_util.getProperty(detectionWithDescriptor, 'landmarks');
      Map<String, Map<String, double>> landmarks = {};
      if (landmarksObj != null) {
        Map<String, double> extractAvg(String methodName) {
          final points = js_util.callMethod(landmarksObj, methodName, []);
          if (points == null) return {};
          final length = js_util.getProperty(points, 'length') ?? 0;
          if (length == 0) return {};
          double sumX = 0, sumY = 0;
          for (int i = 0; i < length; i++) {
            final p = js_util.getProperty(points, i);
            sumX += (js_util.getProperty(p, 'x') ?? 0).toDouble();
            sumY += (js_util.getProperty(p, 'y') ?? 0).toDouble();
          }
          return {'x': sumX / length, 'y': sumY / length};
        }

        landmarks['nose'] = extractAvg('getNose');
        landmarks['leftEye'] = extractAvg('getLeftEye');
        landmarks['rightEye'] = extractAvg('getRightEye');
      }

      // 🧭 Calculate Yaw Angle (left/right rotation)
      double yawAngle = 0.0;
      if (landmarks.containsKey('nose') &&
          landmarks.containsKey('leftEye') &&
          landmarks.containsKey('rightEye')) {
        final nose = landmarks['nose']!;
        final leftEye = landmarks['leftEye']!;
        final rightEye = landmarks['rightEye']!;
        final midX = (leftEye['x']! + rightEye['x']!) / 2;
        final eyeDist = (rightEye['x']! - leftEye['x']!).abs();

        // yaw in degrees
        yawAngle = (math.atan2(nose['x']! - midX, eyeDist) * 180 / math.pi);

        // Debug log
        if (yawAngle.abs() < 5) {
          print("🧭 Facing front (yaw: ${yawAngle.toStringAsFixed(1)}°)");
        } else if (yawAngle > 0) {
          print("↪️ Turned RIGHT (yaw: ${yawAngle.toStringAsFixed(1)}°)");
        } else {
          print("↩️ Turned LEFT (yaw: ${yawAngle.toStringAsFixed(1)}°)");
        }
      }

      // Extract descriptor safely
      final descriptorJs = js_util.getProperty(detectionWithDescriptor, 'descriptor');
      List<double> descriptor = [];
      if (descriptorJs != null && js_util.hasProperty(descriptorJs, 'length')) {
        final length = js_util.getProperty(descriptorJs, 'length') as int;
        descriptor = List.generate(length, (i) {
          final val = js_util.getProperty(descriptorJs, i);
          return (val is num) ? val.toDouble() : 0.0;
        });
      }

      print('✅ Face detected, score: ${score.toStringAsFixed(3)}');
      print('📦 Box: x=$x, y=$y, w=$width, h=$height');
      print('👃 Nose: ${landmarks['nose']}');
      print('🧬 Descriptor length: ${descriptor.length}');
      print('🎯 Yaw angle: ${yawAngle.toStringAsFixed(1)}°');

      return {
        'box': {'x': x, 'y': y, 'width': width, 'height': height},
        'score': score,
        'yaw': yawAngle,
        'landmarks': landmarks,
        'descriptor': descriptor,
      };
    } catch (e, st) {
      print('⚠️ Face detection failed: $e');
      print(st);
      return null;
    }
  }
}
