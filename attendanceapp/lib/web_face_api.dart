import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:async';
import 'package:attendanceapp/configs_and_tools/debug.dart';

class WebFaceApi {
  static Debug debug = Debug(module: "web_face_api", enable: true);

  static const String _cacheVersion = "v1"; // increment when models change
  static final Map<String, List<double>> _descriptorCache = {};

  // IndexedDB database for offline descriptor caching
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

      // ✅ FIX: do NOT use promiseToFuture here, just await the native Future
      _db = await request;
      debug.log("IndexedDB initialized");
    } catch (e) {
      debug.log("⚠️ IndexedDB initialization failed: $e");
      _db = null; // fallback to online mode
    }
  }

  /// Put descriptor to IndexedDB
  static Future<void> _putToDB(String key, String value) async {
    try {
      await _initDB();
      if (_db == null) return; // no offline storage available

      final txn = _db.transaction(_descriptorStore, 'readwrite');
      final store = txn.objectStore(_descriptorStore);
      store.put(value, key);

      await txn.completed;
    } catch (e) {
      debug.log("⚠️ Failed to save descriptor to IndexedDB: $e");
    }
  }

  /// Get descriptor from IndexedDB
  static Future<String?> _getFromDB(String key) async {
    try {
      await _initDB();
      if (_db == null) return null;

      final txn = _db.transaction(_descriptorStore, 'readonly');
      final store = txn.objectStore(_descriptorStore);
      final result = await store.getObject(key);

      return result as String?;
    } catch (e) {
      debug.log("⚠️ IndexedDB read failed: $e");
      return null;
    }
  }

  /// Check cache version
  static Future<void> _checkCacheVersion() async {
    try {
      await _initDB();
      if (_db == null) return; // skip version check if no DB

      final storedVersion = await _getFromDB('cacheVersion');
      if (storedVersion == null) {
        await _putToDB('cacheVersion', _cacheVersion);
        debug.log("Initial cache version stored as $_cacheVersion");
        return;
      }
      if (storedVersion != _cacheVersion) {
        debug.log("Cache version changed. Clearing old cache...");
        _descriptorCache.clear();
        final txn =
        js_util.callMethod(_db, 'transaction', [_descriptorStore, 'readwrite']);
        final store = js_util.callMethod(txn, 'objectStore', [_descriptorStore]);
        js_util.callMethod(store, 'clear', []);
        await js_util.promiseToFuture(
            js_util.getProperty(txn, 'done') ?? js_util.getProperty(txn, 'completed'));
        await _putToDB('cacheVersion', _cacheVersion);
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

  /// Compute face descriptor safely (in-memory + IndexedDB + fallback)
  static Future<List<double>> computeFaceDescriptorSafe(
      html.ImageElement img, {String? cacheKey}) async {
    await _checkCacheVersion();

    // Check in-memory cache
    if (cacheKey != null && _descriptorCache.containsKey(cacheKey)) {
      debug.log("Returning cached descriptor for $cacheKey (memory)");
      return _descriptorCache[cacheKey]!;
    }

    // Try IndexedDB (offline)
    if (cacheKey != null) {
      try {
        final stored = await _getFromDB(cacheKey);
        if (stored != null) {
          final descriptor =
          (stored.split(',')).map((e) => double.parse(e)).toList();
          _descriptorCache[cacheKey] = descriptor;
          debug.log("Returning cached descriptor for $cacheKey (IndexedDB)");
          return descriptor;
        }
      } catch (e) {
        debug.log("⚠️ Failed to get from offline cache: $e");
      }
    }

    // Fallback to online compute
    debug.log("Falling back to online face descriptor computation...");
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
      throw Exception("No descriptor detected");
    }

    final descriptorJs =
    js_util.getProperty(detectionWithDescriptor, 'descriptor');
    final descriptor = (descriptorJs as List).map((e) => e as double).toList();

    // Save to cache if possible
    if (cacheKey != null) {
      _descriptorCache[cacheKey] = descriptor;
      await _putToDB(cacheKey, descriptor.join(','));
    }

    debug.log("Descriptor computed for ${cacheKey ?? 'unknown'}");
    return descriptor;
  }
}
