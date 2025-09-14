import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// Load face-api.js models
Future<void> loadModels({int retries = 5, int delayMs = 500}) async {
  for (var i = 0; i < retries; i++) {
    if (js_util.hasProperty(html.window, 'faceapi')) break;
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  if (!js_util.hasProperty(html.window, 'faceapi')) {
    print("Face-api.js not loaded yet!");
    return;
  }

  try {
    final faceapi = js_util.getProperty(html.window, 'faceapi');

    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(faceapi, 'nets')['ssdMobilenetv1'], 'loadFromUri', ['/models/'])
    );
    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(faceapi, 'nets')['faceLandmark68Net'], 'loadFromUri', ['/models/'])
    );
    await js_util.promiseToFuture(
        js_util.callMethod(js_util.getProperty(faceapi, 'nets')['faceRecognitionNet'], 'loadFromUri', ['/models/'])
    );

    print("Models loaded successfully");
  } catch (e) {
    print("Error loading Face-api.js models: $e");
  }
}

/// Convert Flutter Uint8List to HTML ImageElement
html.ImageElement uint8ListToImage(Uint8List bytes) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final img = html.ImageElement(src: url);
  return img;
}

/// Resize image using Canvas
html.ImageElement resizeImage(html.ImageElement img, int width, int height) {
  final canvas = html.CanvasElement(width: width, height: height);
  canvas.context2D.drawImageScaled(img, 0, 0, width, height);
  return html.ImageElement(src: canvas.toDataUrl());
}

/// Compute face embedding
Future<List<double>> computeFaceDescriptor(html.ImageElement img) async {
  final faceapi = js_util.getProperty(html.window, 'faceapi');
  final descriptor = await js_util.promiseToFuture<List<dynamic>>(
      js_util.callMethod(faceapi, 'computeFaceDescriptor', [img])
  );
  return descriptor.map((e) => e as double).toList();
}