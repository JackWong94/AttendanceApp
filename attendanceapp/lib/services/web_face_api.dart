import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:async';

/// Load face-api.js models
Future<void> loadModels({int retries = 5, int delayMs = 1}) async {
  // Wait until window.faceapi exists
  for (var i = 0; i < retries; i++) {
    if (js_util.hasProperty(html.window, 'faceapi')) break;
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  if (!js_util.hasProperty(html.window, 'faceapi')) {
    throw Exception("Face-api.js not loaded after $retries attempts!");
  }

  try {
    final faceapi = js_util.getProperty(html.window, 'faceapi');

    // === CHANGE 1: use getProperty instead of [] ===
    final nets = js_util.getProperty(faceapi, 'nets');

    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(nets, 'ssdMobilenetv1'), 'loadFromUri', ['/models/'])
    );
    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(nets, 'faceLandmark68Net'), 'loadFromUri', ['/models/'])
    );
    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(nets, 'faceRecognitionNet'), 'loadFromUri', ['/models/'])
    );
    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(nets, 'tinyFaceDetector'), 'loadFromUri', ['/models/'])
    );

    print("Models loaded successfully");
  } catch (e) {
    print("Error loading Face-api.js models: $e");
  }
}

// Convert Uint8List bytes to a fully loaded HTML ImageElement (web)
Future<html.ImageElement> uint8ListToImage(Uint8List bytes) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final img = html.ImageElement(src: url);

  // Wait until the image is fully loaded using decode() -> JS Promise -> Dart Future
  await js_util.promiseToFuture<void>(js_util.callMethod(img, 'decode', []));

  // Free the object URL after loading
  html.Url.revokeObjectUrl(url);

  return img;
}

// Resize image using Canvas (web) and return a Future<ImageElement>
Future<html.ImageElement> resizeImage(html.ImageElement img, int width, int height) {
  final canvas = html.CanvasElement(width: width, height: height);
  canvas.context2D.drawImageScaled(img, 0, 0, width, height);

  final resizedImg = html.ImageElement(src: canvas.toDataUrl());

  // Use JS Promise to Future instead of Completer
  final promise = js_util.promiseToFuture<void>(
    js_util.callMethod(
      resizedImg, 'decode', [], // decode() returns a Promise that resolves when the image is ready
    ),
  );

  return promise.then((_) => resizedImg);
}

/// Compute face embedding safely with exception
Future<List<double>> computeFaceDescriptor(html.ImageElement img) async {
  final faceapi = js_util.getProperty(html.window, 'faceapi');

  if (faceapi == null) throw Exception("face-api.js not loaded");

// === CHANGE 2: Use TinyFaceDetector options properly ===
  final TinyFaceDetectorOptions = js_util.getProperty(faceapi, 'TinyFaceDetectorOptions');
  final options = js_util.callConstructor(TinyFaceDetectorOptions, [
    js_util.jsify({'inputSize': 160, 'scoreThreshold': 0.5}) // optional, adjust if needed
  ]);

// === CHANGE 3: Correct face detection chain ===
  final detection = await js_util.promiseToFuture(
      js_util.callMethod(faceapi, 'detectSingleFace', [img, options])
  );
  if (detection == null) throw Exception("No face detected");

// Add landmarks
  final detectionWithLandmarks = await js_util.promiseToFuture(
      js_util.callMethod(detection, 'withFaceLandmarks', [])
  );

// Add descriptor
  final detectionWithDescriptor = await js_util.promiseToFuture(
      js_util.callMethod(detectionWithLandmarks, 'withFaceDescriptor', [])
  );

// The descriptor array
  final descriptorJs = js_util.getProperty(detectionWithDescriptor, 'descriptor');
  if (descriptorJs == null) throw Exception("Failed to compute descriptor");

// Convert to Dart list
  return (descriptorJs as List).map((e) => e as double).toList();
}