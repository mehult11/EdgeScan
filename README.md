## Receipt Edge Detection App

This Flutter application performs **real-time receipt/document edge detection** using the device camera and **on-device machine learning** (TensorFlow Lite). It captures and highlights document boundaries and allows the user to save captured images.

## Features

- Live camera preview using `camera` plugin
- Real-time edge detection using **DeepLabV3** TFLite model
- Efficient image processing using **Isolate** to avoid UI freeze
- Auto-capture when a document is detected
- Manual capture button
- Saves images locally with timestamped filenames
- Displays bounding rectangle on detected document

## Tech Stack

- **Flutter** 3.16.9
- **TensorFlow Lite Flutter** (tflite_flutter)
- **Camera** plugin for live preview
- **Image** package for pixel manipulation
- **Path Provider** for storage
- **GetX** for navigation and snackbars

## Project Structure
```
lib/
├── main.dart
├── edge_detection_camera.dart     # Main screen and camera logic
├── util/
│   └── edge_detection_isolate.dart  # Isolate logic for inference
```

## Setup Instructions

1. Add the TFLite model:
- Place `model.tflite` inside the `assets/` folder
- Ensure `pubspec.yaml` includes:
```yaml
assets:
  - assets/model.tflite
```

2. Install dependencies:
```bash
flutter pub get
flutter pub run flutter_launcher_icons:main  ## run the command to generate launcher icons:
```

3. Run the app:
```bash
flutter run
```

## Usage
- Point the camera at a document
- A white rectangle will appear when edges are detected
- Use the camera button to manually capture an image
- Images are saved at:
```
Download/EdgeDetection/<timestamp>.jpg
```

