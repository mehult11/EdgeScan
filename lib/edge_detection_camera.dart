/*
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:isolate';
import 'package:rf8_ds/util/edge_detection_isolate.dart';


class EdgeDetectionCamera extends StatefulWidget {
  @override
  _EdgeDetectionCameraState createState() => _EdgeDetectionCameraState();
}

class _EdgeDetectionCameraState extends State<EdgeDetectionCamera> {
  late CameraController _cameraController;
  List<Offset> _rectangle = [];
  bool _isDetecting = false;
  DateTime _lastDetection = DateTime.now();
  late final String dirPath;
  @override
  void initState() {
    super.initState();
    getDirectoryPath().then((value) => dirPath = value);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _cameraController.initialize();
    _cameraController.startImageStream(_runInference);
    setState(() {});
  }

  void _runInference(CameraImage image) async {
    if (_isDetecting || DateTime.now().difference(_lastDetection).inMilliseconds < 500) return;
    _isDetecting = true;
    _lastDetection = DateTime.now();

    try {
      print("📍FLUTTER_LOG: 🟠 Step 1: Converting camera image...");
      final imageData = await _convertCameraImage(image);
      print("📍FLUTTER_LOG: ✅ Step 2: Image converted");

      final receivePort = ReceivePort();
      print("📍FLUTTER_LOG: 🟠 Step 3: Spawning isolate...");
      final isolate = await Isolate.spawn(edgeDetectionIsolate, receivePort.sendPort);

      final sendPort = await receivePort.first as SendPort;
      print("📍FLUTTER_LOG: ✅ Step 4: SendPort received");

      final responsePort = ReceivePort();
      print("📍FLUTTER_LOG: 🟠 Step 5: Sending data to isolate...");
      sendPort.send([
        imageData['modelPathBytes'],
        imageData['resizedImage'],
        responsePort.sendPort
      ]);

      final result = await responsePort.first;
      print("📍FLUTTER_LOG: ✅ Step 6: Received result from isolate");

      if (result is InferenceResult) {
        setState(() {
          _rectangle = result.rectangle;
        });
        print("📍FLUTTER_LOG: ✅ Rectangle detected: ${_rectangle.length} corners");
        if (_rectangle.isNotEmpty) {
          _captureImage();
          for (int i = 0; i < _rectangle.length; i++) {
            print("📍FLUTTER_LOG: 📍 Point $i: ${_rectangle[i]}");
          }
        }
      } else {
        print("📍FLUTTER_LOG: ❌ Invalid result from isolate");
      }
    } catch (e) {
      print("📍FLUTTER_LOG: ❌ Isolate error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  Future<Map<String, dynamic>> _convertCameraImage(CameraImage image) async {
    print("📍FLUTTER_LOG: 🔄 Converting YUV420 to RGB");
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final imgBuffer = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * image.planes[0].bytesPerRow + x;
        final uvIndex = (y ~/ 2) * image.planes[1].bytesPerRow + (x ~/ 2) * image.planes[1].bytesPerPixel!;

        final yValue = yPlane[yIndex];
        final uValue = uPlane[uvIndex];
        final vValue = vPlane[uvIndex];

        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        imgBuffer.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    print("📍FLUTTER_LOG: 📏 Resizing image to 257x257");
    final resized = img.copyResize(imgBuffer, width: 257, height: 257);

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

    print("📍FLUTTER_LOG: 📦 Loading model bytes");
    final byteData = await DefaultAssetBundle.of(context).load('assets/model.tflite');
    final buffer = byteData.buffer;

    print("📍FLUTTER_LOG: ✅ Image processing complete");
    return {
      'modelPathBytes': buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      'resizedImage': resized
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cameraController.value.isInitialized
          ? Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController),
          CustomPaint(
            painter: RectanglePainter(_rectangle),
          ),
          Positioned(
            bottom: 30,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: FloatingActionButton(
              onPressed: _captureImage,
              child: Icon(Icons.camera_alt),
            ),
          ),
        ],
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      print("📸 Starting image capture");
      final file = await _cameraController!.takePicture();
      final originalBytes = await file.readAsBytes();
      final original = img.decodeImage(originalBytes);

      if (original == null) {
        print("❌ Failed to decode captured image");
        return;
      }

      final originalWidth = original.width;
      final originalHeight = original.height;

      // Scaling factors from model size (257x257) to actual image size
      final scaleX = originalWidth / 257.0;
      final scaleY = originalHeight / 257.0;

      final x = (_rectangle[0].dx * scaleX).toInt();
      final y = (_rectangle[0].dy * scaleY).toInt();
      final width = ((_rectangle[2].dx - _rectangle[0].dx) * scaleX).toInt();
      final height = ((_rectangle[2].dy - _rectangle[0].dy) * scaleY).toInt();

      // Clamp values to avoid overflow
      final clampedX = x.clamp(0, originalWidth - 1);
      final clampedY = y.clamp(0, originalHeight - 1);
      final clampedWidth = (clampedX + width > originalWidth)
          ? originalWidth - clampedX
          : width;
      final clampedHeight = (clampedY + height > originalHeight)
          ? originalHeight - clampedY
          : height;

      final cropped = img.copyCrop(
        original,
        x: clampedX,
        y: clampedY,
        width: clampedWidth,
        height: clampedHeight,
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '/storage/emulated/0/Download/EdgeDetection';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '$path/$timestamp.jpg';
      final savedFile = File(filePath);
      await savedFile.writeAsBytes(img.encodeJpg(cropped));

      print("✅ Image saved to $filePath");
    } catch (e) {
      print("❌ Error capturing image: $e");
    }
  }


  Future<String> getDirectoryPath() async {
    final directory = Directory('/storage/emulated/0/Download/EdgeDetection');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}

class RectanglePainter extends CustomPainter {
  final List<Offset> points;
  RectanglePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) return;

    // 🔁 Scale model 257x257 output to camera preview size
    final scaleX = size.width / 257.0;
    final scaleY = size.height / 257.0;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    final path = Path()
      ..moveTo(points[0].dx * scaleX, points[0].dy * scaleY)
      ..lineTo(points[1].dx * scaleX, points[1].dy * scaleY)
      ..lineTo(points[2].dx * scaleX, points[2].dy * scaleY)
      ..lineTo(points[3].dx * scaleX, points[3].dy * scaleY)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
*/
// edge_detection_camera.dart

// edge_detection_camera.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:rf8_ds/util/edge_detection_isolate.dart';

class EdgeDetectionCamera extends StatefulWidget {
  @override
  _EdgeDetectionCameraState createState() => _EdgeDetectionCameraState();
}

class _EdgeDetectionCameraState extends State<EdgeDetectionCamera> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  List<Offset> _rectangle = [];
  DateTime _lastDetection = DateTime.now();
  late Uint8List _modelBytes;
  SendPort? _isolateSendPort;

  @override
  void initState() {
    super.initState();
    _loadModelAndStartIsolate();
  }

  // Load the TFLite model and start isolate
  Future<void> _loadModelAndStartIsolate() async {
    final byteData = await rootBundle.load('assets/model.tflite');
    _modelBytes = byteData.buffer.asUint8List();

    final receivePort = ReceivePort();
    await Isolate.spawn(edgeDetectionIsolate, receivePort.sendPort);

    _isolateSendPort = await receivePort.first;
    _initializeCamera();
  }

  // Initialize camera and start image stream
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _cameraController!.initialize();
    _cameraController!.startImageStream(_processCameraImage);
    setState(() {});
  }

  // Send camera frame to isolate for inference
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || DateTime.now().difference(_lastDetection).inMilliseconds < 800) return;
    _isDetecting = true;
    _lastDetection = DateTime.now();

    try {
      final converted = _convertYUV420ToImage(image);

      final responsePort = ReceivePort();
      _isolateSendPort?.send([_modelBytes, converted, responsePort.sendPort]);

      final result = await responsePort.first;
      if (result is InferenceResult && result.rectangle.isNotEmpty) {
        setState(() => _rectangle = result.rectangle);
      }
    } catch (_) {} finally {
      _isDetecting = false;
    }
  }

  // Convert YUV420 image format to RGB
  img.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    final imgBuffer = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * image.planes[0].bytesPerRow + x;
        final uvIndex = (y ~/ 2) * image.planes[1].bytesPerRow + (x ~/ 2) * image.planes[1].bytesPerPixel!;

        final yValue = yPlane[yIndex];
        final uValue = uPlane[uvIndex];
        final vValue = vPlane[uvIndex];

        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        imgBuffer.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return imgBuffer;
  }

  // Capture image and show saved path via snackbar
  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      print("📸 Starting image capture");
      final file = await _cameraController!.takePicture();
      final originalBytes = await file.readAsBytes();
      final original = img.decodeImage(originalBytes);

      if (original == null) {
        print("❌ Failed to decode captured image");
        return;
      }

      final originalWidth = original.width;
      final originalHeight = original.height;

      // Scaling factors from model size (257x257) to actual image size
      final scaleX = originalWidth / 257.0;
      final scaleY = originalHeight / 257.0;

      final x = (_rectangle[0].dx * scaleX).toInt();
      final y = (_rectangle[0].dy * scaleY).toInt();
      final width = ((_rectangle[2].dx - _rectangle[0].dx) * scaleX).toInt();
      final height = ((_rectangle[2].dy - _rectangle[0].dy) * scaleY).toInt();

      // Clamp values to avoid overflow
      final clampedX = x.clamp(0, originalWidth - 1);
      final clampedY = y.clamp(0, originalHeight - 1);
      final clampedWidth = (clampedX + width > originalWidth)
          ? originalWidth - clampedX
          : width;
      final clampedHeight = (clampedY + height > originalHeight)
          ? originalHeight - clampedY
          : height;

      final cropped = img.copyCrop(
        original,
        x: clampedX,
        y: clampedY,
        width: clampedWidth,
        height: clampedHeight,
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '/storage/emulated/0/Download/EdgeDetection';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '$path/$timestamp.jpg';
      final savedFile = File(filePath);
      await savedFile.writeAsBytes(img.encodeJpg(cropped));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📸 Image stored at $filePath')),
        );
      }
    } catch (e) {
      print("❌ Error capturing image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cameraController?.value.isInitialized == true
          ? Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          CustomPaint(painter: RectanglePainter(_rectangle)),
          Positioned(
            bottom: 30,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: FloatingActionButton(
              onPressed: _captureImage,
              child: Icon(Icons.camera_alt),
            ),
          ),
        ],
      )
          : Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}

class RectanglePainter extends CustomPainter {
  final List<Offset> points;
  RectanglePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) return;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
