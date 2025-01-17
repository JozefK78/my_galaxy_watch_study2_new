// lib/main.dart

import 'package:flutter/material.dart';
import 'ball_simulator.dart'; // Import the BallSimulator widget

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wear OS Ball Simulator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BallSimulator(),
    );
  }
}
