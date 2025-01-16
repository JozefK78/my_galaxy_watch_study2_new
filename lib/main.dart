import 'package:flutter/material.dart';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';

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

class BallSimulator extends StatefulWidget {
  @override
  _BallSimulatorState createState() => _BallSimulatorState();
}

class _BallSimulatorState extends State<BallSimulator> {
  late Offset _ballPosition; // Ball's position on the screen
  late double _screenWidth;
  late double _screenHeight;
  double _ballRadius = 20;
  double _arrowRotation = 0.0; // Rotation for the arrow
  double _sensorMagnitude = 0.0; // Sensor magnitude

  @override
  void initState() {
    super.initState();
    _ballPosition = Offset(0, 0); // Initial ball position

    // Enable wakelock to keep the screen awake
    WakelockPlus.enable();

    accelerometerEvents.listen(_updateBallPosition);
  }

  @override
  void dispose() {
    // Disable wakelock when the app is closed
    WakelockPlus.disable();
    super.dispose();
  }

  void _updateBallPosition(AccelerometerEvent event) {
    setState(() {
      // Map accelerometer data to screen coordinates
      double x = event.x * 2; // Adjust sensitivity
      double y = event.y * 2;

      // Update potential new position
      Offset newPosition = Offset(
        _ballPosition.dx - x,
        _ballPosition.dy + y,
      );

      // Calculate distance from the center
      double distanceFromCenter = newPosition.distance;

      // Ensure the ball stays within the circular boundary
      double radius = (_screenWidth / 2) - _ballRadius;
      if (distanceFromCenter <= radius) {
        _ballPosition = newPosition;
      } else {
        // Clamp to circular boundary
        double angle = atan2(newPosition.dy, newPosition.dx);
        _ballPosition = Offset(
          radius * cos(angle),
          radius * sin(angle),
        );
      }

      // Update arrow rotation (atan2 gives direction in radians)
      _arrowRotation = atan2(y, x);
      _sensorMagnitude = sqrt(x * x + y * y); // Calculate magnitude
    });
  }

  void _resetBall() {
    setState(() {
      _ballPosition = Offset(0, 0); // Reset ball to center
    });
  }

  void _exitApp() {
    // Disable wakelock before exiting
    WakelockPlus.disable();
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Ball
          Positioned(
            left: (_screenWidth / 2 + _ballPosition.dx) - _ballRadius,
            top: (_screenHeight / 2 + _ballPosition.dy) - _ballRadius,
            child: Container(
              width: _ballRadius * 2,
              height: _ballRadius * 2,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Arrow
          Positioned(
            left: _screenWidth / 2 - 15,
            top: _screenHeight / 2 - 70,
            child: Transform.rotate(
              angle: _arrowRotation,
              child: Icon(
                Icons.arrow_upward,
                size: 30,
                color: Colors.red,
              ),
            ),
          ),
          // Sensor data
          Positioned(
            left: _screenWidth / 2 - 40,
            top: _screenHeight / 2 + 50,
            child: Text(
              _sensorMagnitude.toStringAsFixed(2), // Show magnitude with 2 decimals
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
      // Top and bottom button handling
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top button: Reset ball
          FloatingActionButton(
            onPressed: _resetBall,
            child: Icon(Icons.center_focus_strong),
            backgroundColor: Colors.green,
          ),
          // Bottom button: Exit app
          FloatingActionButton(
            onPressed: _exitApp,
            child: Icon(Icons.exit_to_app),
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
  }
}
