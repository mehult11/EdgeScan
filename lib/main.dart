import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rf8_ds/home_page.dart';

void main() async{

  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Receipt Edge Detection',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

