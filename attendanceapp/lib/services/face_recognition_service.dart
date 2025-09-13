import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  late Interpreter _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('mobilefacenet.tflite');
  }

  List<double> getEmbedding(Uint8List imageBytes) {
    // Preprocess image -> Float32 input tensor
    // This part depends on the model input size (usually 112x112)
    var input = _preprocessImage(imageBytes);

    var output = List.generate(1, (_) => List.filled(128, 0.0));
    _interpreter.run(input, output);

    return output[0];
  }

  List<List<List<List<double>>>> _preprocessImage(Uint8List imageBytes) {
    // TODO: Resize, normalize image to 112x112
    // return proper tensor format
    throw UnimplementedError();
  }
}
