import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:async';
import 'package:attendanceapp/configs_and_tools/debug.dart';

class WebFaceApi {
  static Debug debug = Debug(module: "web_face_api", enable: true);

  /// Current version of the face model / cache
  static const String _cacheVersion = "v4"; // increment this when models change

  /// Cache descriptors to skip recomputation
  static final Map<String, List<double>> _descriptorCache = {};

  /// Check cache version and clear if outdated
  static void _checkCacheVersion() {
    final storedVersion = html.window.localStorage['faceCacheVersion'];

    if (storedVersion == null) {
      // First-time initialization
      html.window.localStorage['faceCacheVersion'] = _cacheVersion;
      debug.log("Initial cache version stored as $_cacheVersion");
      return;
    }

    if (storedVersion != _cacheVersion) {
      debug.log("Stored cache version: $storedVersion, Latest cache version: $_cacheVersion");
      debug.log("Cache version changed. Clearing old descriptor cache...");
      _descriptorCache.clear();
      html.window.localStorage['faceCacheVersion'] = _cacheVersion;
      debug.log("Cache version updated to $_cacheVersion");
    }
  }

  /// Determine the model path dynamically
  static String getModelPath({String modelsFolder = "models"}) {
    final path = html.window.location.pathname ?? "/";
    final normalizedPath = path.endsWith("/") ? path : "$path/";
    if (normalizedPath.endsWith("$modelsFolder/")) return normalizedPath;
    return "$normalizedPath$modelsFolder/";
  }

  /// Load face-api.js models
  static Future<void> loadModels({int retries = 20, int delayMs = 50}) async {
    _checkCacheVersion(); // ensure cache version

    debug.timeStart("loadModels");

    // Wait for faceapi to be available
    for (var i = 0; i < retries; i++) {
      if (js_util.hasProperty(html.window, 'faceapi')) break;
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (!js_util.hasProperty(html.window, 'faceapi')) {
      throw Exception("Face-api.js not loaded after $retries attempts!");
    }

    try {
      final faceapi = js_util.getProperty(html.window, 'faceapi');
      final nets = js_util.getProperty(faceapi, 'nets');
      final modelPath = getModelPath();

      // Load all models in parallel
      await Future.wait([
        js_util.promiseToFuture(
            js_util.callMethod(js_util.getProperty(nets, 'ssdMobilenetv1'), 'loadFromUri', [modelPath])),
        js_util.promiseToFuture(
            js_util.callMethod(js_util.getProperty(nets, 'faceLandmark68Net'), 'loadFromUri', [modelPath])),
        js_util.promiseToFuture(
            js_util.callMethod(js_util.getProperty(nets, 'faceRecognitionNet'), 'loadFromUri', [modelPath])),
        js_util.promiseToFuture(
            js_util.callMethod(js_util.getProperty(nets, 'tinyFaceDetector'), 'loadFromUri', [modelPath])),
      ]);

      debug.log("Models loaded successfully");
      debug.timeEnd("loadModels");
    } catch (e) {
      debug.log("Error loading Face-api.js models: $e");
    }
  }

  /// Convert Uint8List bytes to a fully loaded HTML ImageElement
  static Future<html.ImageElement> uint8ListToImage(Uint8List bytes) async {
    _checkCacheVersion(); // ensure cache version

    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement(src: url);

    await js_util.promiseToFuture<void>(js_util.callMethod(img, 'decode', []));
    html.Url.revokeObjectUrl(url);
    return img;
  }

  /// Resize image using Canvas (web) and return a Future<ImageElement>
  static Future<html.ImageElement> resizeImage(html.ImageElement img, int width, int height) {
    _checkCacheVersion(); // ensure cache version

    final canvas = html.CanvasElement(width: width, height: height);
    canvas.context2D.drawImageScaled(img, 0, 0, width, height);

    final resizedImg = html.ImageElement(src: canvas.toDataUrl());
    return js_util.promiseToFuture<void>(js_util.callMethod(resizedImg, 'decode', [])).then((_) => resizedImg);
  }

  /// Compute face embedding with TinyFaceDetector
  static Future<List<double>> computeFaceDescriptorSafe(
      html.ImageElement img, {
        String? cacheKey,
      }) async {
    _checkCacheVersion(); // ensure cache version

    // Return cached descriptor if available
    if (cacheKey != null && _descriptorCache.containsKey(cacheKey)) {
      debug.log("Returning cached descriptor for $cacheKey");
      return _descriptorCache[cacheKey]!;
    }

    debug.timeStart("Step 1");
    final faceapi = js_util.getProperty(html.window, 'faceapi');
    if (faceapi == null) throw Exception("Face-api.js not loaded");

    final options = js_util.callConstructor(
      js_util.getProperty(faceapi, 'TinyFaceDetectorOptions'),
      [js_util.jsify({'inputSize': 160, 'scoreThreshold': 0.1})],
    );
    debug.log("Step 1: TinyFaceDetector options created");
    debug.timeEnd("Step 1");

    debug.timeStart("Step 2-4");
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
    debug.log("Step 2–4: Run pipeline in one chain (face -> landmarks -> descriptor)");
    debug.timeEnd("Step 2-4");

    if (detectionWithDescriptor == null) throw Exception("Pipeline failed: no descriptor result");

    debug.timeStart("Step 5");
    final descriptorJs = js_util.getProperty(detectionWithDescriptor, 'descriptor');
    if (descriptorJs == null) throw Exception("Descriptor property missing");
    debug.timeEnd("Step 5");

    final descriptor = (descriptorJs as List).map((e) => e as double).toList();

    // Store in cache
    if (cacheKey != null) _descriptorCache[cacheKey] = descriptor;

    debug.log("Pipeline complete: Descriptor computed");
    return descriptor;
  }
}
