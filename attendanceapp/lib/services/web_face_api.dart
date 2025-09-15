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

/// Compute face embedding safely with exception, debug download included (TinyFaceDetector)
Future<List<double>> computeFaceDescriptorSafe(html.ImageElement img) async {
  final faceapi = js_util.getProperty(html.window, 'faceapi');
  if (faceapi == null) throw Exception("Step 0: face-api.js not loaded");

  // Step 1: create TinyFaceDetector options
  final options = js_util.callConstructor(
    js_util.getProperty(faceapi, 'TinyFaceDetectorOptions'),
    [js_util.jsify({
      'inputSize': 160,      // matches your image size
      'scoreThreshold': 0.1, // very easy detection
    })],
  );
  print("Step 1: TinyFaceDetector options created");

  // Step 1.5: download the image for debugging
  try {
    final anchor = html.AnchorElement(href: img.src)
      ..download = "debug_face.png"
      ..click();
    print("Step 1.5: Image downloaded for debug");
  } catch (e) {
    print("Warning: Failed to download image for debug: $e");
  }

  try {
    // Step 2: detect single face using TinyFaceDetector
    final detection = await js_util.promiseToFuture(
      js_util.callMethod(faceapi, 'detectSingleFace', [img, options]),
    );

    if (detection == null) {
      throw Exception("Step 2: No face detected");
    }
    print("Step 2: Face detected");

    // Step 3: add landmarks
    final detectionWithLandmarks = await js_util.promiseToFuture(
      js_util.callMethod(detection, 'withFaceLandmarks', []),
    );
    if (detectionWithLandmarks == null) {
      throw Exception("Step 3: Failed to add landmarks");
    }
    print("Step 3: Landmarks added");

    // Step 4: add descriptor
    final detectionWithDescriptor = await js_util.promiseToFuture(
      js_util.callMethod(detectionWithLandmarks, 'withFaceDescriptor', []),
    );
    if (detectionWithDescriptor == null) {
      throw Exception("Step 4: Failed to compute descriptor");
    }
    print("Step 4: Descriptor computed");

    final descriptorJs = js_util.getProperty(detectionWithDescriptor, 'descriptor');
    if (descriptorJs == null) throw Exception("Step 5: Descriptor is null");

    print("Step 5: Descriptor retrieved successfully");
    return (descriptorJs as List<dynamic>).map((e) => e as double).toList();
  } catch (e) {
    print("Error during face processing: $e");
    rethrow;
  }
}
