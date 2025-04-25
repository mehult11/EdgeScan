import 'package:flutter/material.dart';
import 'package:rf8_ds/edge_detection_camera.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('EdgeScan',style: TextStyle(color: Colors.white)),
      ),
      body: EdgeDetectionCamera(),
    );
  }
}