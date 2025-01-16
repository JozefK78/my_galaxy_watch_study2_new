import 'package:flutter/material.dart';
import 'ball_simulator.dart'; // Import the BallSimulator widget

void main() {
  runApp(const WearOSBallApp());
}

class WearOSBallApp extends StatelessWidget {
  const WearOSBallApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: BallSimulator(),
    );
  }
}
