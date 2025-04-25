import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class InferenceResult {
  final List<Offset> rectangle;
  InferenceResult(this.rectangle);
}

void edgeDetectionIsolate(SendPort sendPort) async {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  await for (final message in port) {
    final modelBytes = message[0] as Uint8List;
    final img.Image inputImage = message[1] as img.Image;
    final SendPort replyPort = message[2];

    try {
      final interpreter = Interpreter.fromBuffer(modelBytes);

      final resized = img.copyResize(inputImage, width: 257, height: 257);
      final input = Float32List(1 * 257 * 257 * 3);
      int idx = 0;
      for (int y = 0; y < 257; y++) {
        for (int x = 0; x < 257; x++) {
          final pixel = resized.getPixel(x, y);
          input[idx++] = pixel.r / 255.0;
          input[idx++] = pixel.g / 255.0;
          input[idx++] = pixel.b / 255.0;
        }
      }

      final inputTensor = input.reshape([1, 257, 257, 3]);
      final output = List.generate(1 * 257 * 257 * 21, (_) => 0.0).reshape([1, 257, 257, 21]);
      interpreter.run(inputTensor, output);

      final mask = List.generate(257, (y) => List<int>.filled(257, 0));
      for (int y = 0; y < 257; y++) {
        for (int x = 0; x < 257; x++) {
          int bestClass = 0;
          double maxVal = output[0][y][x][0];
          for (int c = 1; c < 21; c++) {
            if (output[0][y][x][c] > maxVal) {
              bestClass = c;
              maxVal = output[0][y][x][c];
            }
          }
          mask[y][x] = bestClass;
        }
      }

      int top = 257, bottom = 0, left = 257, right = 0;
      bool found = false;
      for (int y = 0; y < 257; y++) {
        for (int x = 0; x < 257; x++) {
          if (mask[y][x] == 15) {
            found = true;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
            if (x < left) left = x;
            if (x > right) right = x;
          }
        }
      }

      final rectangle = found
          ? [
        Offset(left.toDouble(), top.toDouble()),
        Offset(right.toDouble(), top.toDouble()),
        Offset(right.toDouble(), bottom.toDouble()),
        Offset(left.toDouble(), bottom.toDouble()),
      ]
          : [];

      replyPort.send(InferenceResult(rectangle as List<Offset>));
    } catch (e) {
      replyPort.send(InferenceResult([]));
    }
  }
}