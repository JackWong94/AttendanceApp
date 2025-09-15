import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:async';

String getModelPath() {
  final path = html.window.location.pathname ?? "";
  // If served under GitHub Pages (/AttendanceApp/), use that
  if (path.startsWith('/AttendanceApp/')) {
    return '/AttendanceApp/models/';
  } else {
    return '/models/';
  }
}

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

    final modelPath = getModelPath();

    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(nets, 'ssdMobilenetv1'), 'loadFromUri', [modelPath])
    );
    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(nets, 'faceLandmark68Net'), 'loadFromUri', [modelPath])
    );
    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(nets, 'faceRecognitionNet'), 'loadFromUri', [modelPath])
    );
    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(nets, 'tinyFaceDetector'), 'loadFromUri', [modelPath])
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

/// Compute face embedding with TinyFaceDetector (all-in-one chain)
Future<List<double>> computeFaceDescriptorSafe(html.ImageElement img) async {
  final faceapi = js_util.getProperty(html.window, 'faceapi');
  if (faceapi == null) throw Exception("Step 0: face-api.js not loaded");

  // Step 1: TinyFaceDetector options
  final options = js_util.callConstructor(
    js_util.getProperty(faceapi, 'TinyFaceDetectorOptions'),
    [js_util.jsify({
      'inputSize': 160,
      'scoreThreshold': 0.1,
    })],
  );
  print("Step 1: TinyFaceDetector options created");

  // Step 1.5: Download image for debugging
  /*
  try {
    final anchor = html.AnchorElement(href: img.src)
      ..download = "debug_face.png"
      ..click();
    print("Step 1.5: Debug image downloaded");
  } catch (e) {
    print("Warning: Failed to download debug image: $e");
  }*/

  try {
    // Step 2–4: Run pipeline in one chain (face -> landmarks -> descriptor)
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
      throw Exception("Pipeline failed: no descriptor result");
    }
    print("Pipeline complete: Descriptor computed");

    // Step 5: Extract descriptor
    final descriptorJs = js_util.getProperty(detectionWithDescriptor, 'descriptor');
    if (descriptorJs == null) throw Exception("Descriptor property missing");

    return (descriptorJs as List).map((e) => e as double).toList();
  } catch (e) {
    print("Error in pipeline: $e");
    rethrow;
  }
}

