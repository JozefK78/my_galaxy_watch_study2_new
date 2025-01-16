// lib/ball_simulator.dart

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'ball_physics.dart'; // Import the BallPhysics class
import 'dart:developer' as developer;

class BallSimulator extends StatefulWidget {
  @override
  _BallSimulatorState createState() => _BallSimulatorState();
}

class _BallSimulatorState extends State<BallSimulator> with SingleTickerProviderStateMixin {
  List<BallPhysics> _balls = []; // List to hold multiple balls
  late double _screenWidth;
  late double _screenHeight;
  final double _ballRadius = 15;

  // Sensitivity factor to control acceleration response
  final double _sensitivity = 150; // Adjust as needed

  // Low-pass filter parameters
  double _filteredAccelX = 0;
  double _filteredAccelY = 0;
  final double _filterAlpha = 0.3;

  late Ticker _ticker;

  // Variables to display accelerometer data
  double _rawAccelX = 0;
  double _rawAccelY = 0;

  // Calibration variables
  bool _isCalibrated = false;
  Offset _calibrationOffset = Offset.zero;

  @override
  void initState() {
    super.initState();

    // Enable wakelock to prevent the screen from sleeping
    WakelockPlus.enable();

    // Initialize ticker
    _ticker = this.createTicker(_onTick);
    _ticker.start();

    // Listen to accelerometer events
    accelerometerEvents.listen((event) {
      setState(() {
        // Store raw accelerometer data for display
        _rawAccelX = event.x;
        _rawAccelY = event.y;

        // Apply low-pass filter to smooth accelerometer data
        _filteredAccelX = _lowPassFilter(_filteredAccelX, event.x, _filterAlpha);
        _filteredAccelY = _lowPassFilter(_filteredAccelY, event.y, _filterAlpha);
      });
    });

    // Initialize balls after first frame
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _initializeBalls();
    });
  }

  /// Initializes the balls at different positions
  void _initializeBalls() {
    // Ensure screen dimensions are available
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    setState(() {
      _balls = [
        BallPhysics(
          position: Offset.zero,
          velocity: Offset.zero,
          radius: _ballRadius,
          boundaryRadius: min(_screenWidth, _screenHeight) / 2 - _ballRadius,
          damping: 0.96,
          friction: 0.98,
          mass: 2.0, // Higher mass
          restitution: 1.0, // Perfectly elastic
        ),
        BallPhysics(
          position: Offset(_ballRadius * 4, _ballRadius * 4), // Different starting position
          velocity: Offset.zero,
          radius: _ballRadius,
          boundaryRadius: min(_screenWidth, _screenHeight) / 2 - _ballRadius,
          damping: 0.96,
          friction: 0.98,
          mass: 2.0, // Higher mass
          restitution: 1.0, // Perfectly elastic
          color: Colors.green, // Different color for distinction
        ),
      ];
    });
  }

  /// Ticker callback to update the physics simulation
  void _onTick(Duration elapsed) {
    // Initialize calibration and balls
    if (!_isCalibrated) {
      if (_balls.isNotEmpty) {
        _calibrationOffset = Offset(_filteredAccelX, _filteredAccelY);
        _isCalibrated = true;
        developer.log('Calibration Offset: $_calibrationOffset');
      }
    }

    if (!_isCalibrated) return; // Skip updates until calibration

    // Calculate adjusted acceleration by removing calibration offset
    Offset adjustedAccel = Offset(_filteredAccelX, _filteredAccelY) - _calibrationOffset;

    // Invert Y-axis to align tilting down with positive screen Y movement
    Offset acceleration = Offset(adjustedAccel.dx, -adjustedAccel.dy) * _sensitivity;

    // Apply acceleration to each ball
    for (var ball in _balls) {
      ball.applyAcceleration(acceleration);
      ball.updatePosition();
    }

    // Handle ball-ball collisions
    _handleBallCollisions();

    // Log position and velocity for debugging
    for (int i = 0; i < _balls.length; i++) {
      developer.log('Ball $i - Position: ${_balls[i].position}, Velocity: ${_balls[i].velocity}');
    }

    // Trigger a rebuild for rendering
    setState(() {});
  }

  /// Handles collisions between balls
  void _handleBallCollisions() {
    for (int i = 0; i < _balls.length; i++) {
      for (int j = i + 1; j < _balls.length; j++) {
        BallPhysics ball1 = _balls[i];
        BallPhysics ball2 = _balls[j];

        double distance = (ball1.position - ball2.position).distance;
        double minDistance = ball1.radius + ball2.radius;

        if (distance < minDistance) {
          // Calculate normal and tangent vectors
          Offset normal = (ball2.position - ball1.position) / distance;
          Offset tangent = Offset(-normal.dy, normal.dx);

          // Project velocities onto the normal and tangent vectors
          double v1n = ball1.velocity.dx * normal.dx + ball1.velocity.dy * normal.dy;
          double v1t = ball1.velocity.dx * tangent.dx + ball1.velocity.dy * tangent.dy;
          double v2n = ball2.velocity.dx * normal.dx + ball2.velocity.dy * normal.dy;
          double v2t = ball2.velocity.dx * tangent.dx + ball2.velocity.dy * tangent.dy;

          // Calculate new normal velocities after collision using 1D elastic collision equations
          double v1nAfter = (v1n * (ball1.mass - ball2.mass) + 2 * ball2.mass * v2n) / (ball1.mass + ball2.mass);
          double v2nAfter = (v2n * (ball2.mass - ball1.mass) + 2 * ball1.mass * v1n) / (ball1.mass + ball2.mass);

          // Convert scalar normal and tangential velocities into vectors
          Offset v1nAfterVec = normal * v1nAfter;
          Offset v1tAfterVec = tangent * v1t;
          Offset v2nAfterVec = normal * v2nAfter;
          Offset v2tAfterVec = tangent * v2t;

          // Update velocities by combining normal and tangential components
          ball1.velocity = v1nAfterVec + v1tAfterVec;
          ball2.velocity = v2nAfterVec + v2tAfterVec;

          // Adjust positions to prevent sticking
          double overlap = minDistance - distance;
          Offset displacement = normal * (overlap / 2);
          ball1.position -= displacement;
          ball2.position += displacement;

          // Optional: Change colors to indicate collision
          ball1.color = Colors.red;
          ball2.color = Colors.red;

          // Reset colors after a short duration
          ball1._resetColor();
          ball2._resetColor();
        }
      }
    }
  }

  // Low-pass filter to smooth accelerometer data
  double _lowPassFilter(double current, double newValue, double alpha) {
    return current * (1.0 - alpha) + newValue * alpha;
  }

  @override
  void dispose() {
    // Disable wakelock when the app is closed
    WakelockPlus.disable();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Render all balls
          ..._balls.map((ball) {
            return Center(
              child: Transform.translate(
                offset: ball.position,
                child: Container(
                  width: ball.radius * 2,
                  height: ball.radius * 2,
                  decoration: BoxDecoration(
                    color: ball.color, // Use the ball's current color
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }).toList(),
          // Display accelerometer data for debugging
          Positioned(
            top: 10,
            left: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Raw Accel X: ${_rawAccelX.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  'Raw Accel Y: ${_rawAccelY.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  'Filtered Accel X: ${_filteredAccelX.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  'Filtered Accel Y: ${_filteredAccelY.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                // Display calibrated accelerometer data
                if (_isCalibrated)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calibrated Accel X: ${(Offset(_filteredAccelX, _filteredAccelY) - _calibrationOffset).dx.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      Text(
                        'Calibrated Accel Y: ${(Offset(_filteredAccelX, _filteredAccelY) - _calibrationOffset).dy.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Add a Floating Action Button to reset calibration and balls
          Positioned(
            bottom: 10,
            right: 10,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isCalibrated = false;
                  _calibrationOffset = Offset.zero;
                  _balls.forEach((ball) => ball.reset());
                  _balls.clear();
                  _initializeBalls();
                });
              },
              child: Icon(Icons.refresh),
              mini: true,
            ),
          ),
        ],
      ),
    );
  }
}
