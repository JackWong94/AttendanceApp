@JS()
library web_face_api;

import 'dart:typed_data';
import 'dart:html' as html;
import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS('faceapi')
external dynamic get faceapi;

/// Load face-api.js models
Future<void> loadModels() async {
  await promiseToFuture(faceapi.nets.ssdMobilenetv1.loadFromUri('/models/'));
  await promiseToFuture(faceapi.nets.faceLandmark68Net.loadFromUri('/models/'));
  await promiseToFuture(faceapi.nets.faceRecognitionNet.loadFromUri('/models/'));
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
  final descriptor = await promiseToFuture<List<dynamic>>(faceapi.computeFaceDescriptor(img));
  return descriptor.map((e) => e as double).toList();
}
