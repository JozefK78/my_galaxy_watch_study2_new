import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

class _BallSimulatorState extends State<BallSimulator> with SingleTickerProviderStateMixin {
  late Offset _ballPosition; // Ball's position on the screen
  late double _screenWidth;
  late double _screenHeight;
  double _ballRadius = 15;

  double _vx = 0; // Ball velocity in the x direction
  double _vy = 0; // Ball velocity in the y direction

  @override
  void initState() {
    super.initState();

    // Enable wakelock to prevent the screen from sleeping
    WakelockPlus.enable();

    // Initialize the ball's position at the center
    _ballPosition = Offset(0, 0);

    // Listen to accelerometer events for velocity updates
    accelerometerEvents.listen((event) {
      _vx = _lowPassFilter(_vx, event.x * 3, 0.1); // Adjust sensitivity
      _vy = _lowPassFilter(_vy, event.y * 3, 0.1); // Adjust sensitivity
    });

    // Use a ticker to update the ball's position at a constant frame rate
    Ticker _ticker = this.createTicker((elapsed) {
      setState(() {
        _updateBallPosition();
      });
    });

    _ticker.start();


  }

  // Low-pass filter to smooth accelerometer data
  double _lowPassFilter(double current, double newValue, double alpha) {
    return current * (1.0 - alpha) + newValue * alpha;
  }

  void _updateBallPosition() {
    const double damping = 0.95;

    // Apply damping to slow down the ball gradually
    _vx *= damping;
    _vy *= damping;

    // Calculate the new position
    Offset newPosition = Offset(
      _ballPosition.dx + _vx,
      _ballPosition.dy + _vy,
    );

    // Define the circular boundary (radius)
    double radius = (_screenWidth / 2) - _ballRadius;
    double distanceFromCenter = newPosition.distance;

    if (distanceFromCenter >= radius) {
      // Ball hits the edge, bounce back
      double angle = atan2(newPosition.dy, newPosition.dx);
      _vx = -_vx; // Reverse x velocity
      _vy = -_vy; // Reverse y velocity

      // Clamp the ball to the boundary
      _ballPosition = Offset(
        radius * cos(angle),
        radius * sin(angle),
      );
    } else {
      // Update position if within bounds
      _ballPosition = newPosition;
    }
  }

  @override
  void dispose() {
    // Disable wakelock when the app is closed
    WakelockPlus.disable();
    super.dispose();
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
        ],
      ),
    );
  }
}
