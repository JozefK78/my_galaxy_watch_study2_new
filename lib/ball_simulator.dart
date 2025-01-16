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
  BallPhysics? _ballPhysics;
  late double _screenWidth;
  late double _screenHeight;
  final double _ballRadius = 15;

  // Sensitivity factor to control acceleration response
  final double _sensitivity = 20; // Reduced from 500

  // Low-pass filter parameters
  double _filteredAccelX = 0;
  double _filteredAccelY = 0;
  final double _filterAlpha = 0.3; // Increased from 0.2

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
  }

  /// Ticker callback to update the physics simulation
  void _onTick(Duration elapsed) {
    // Ensure screen dimensions are available
    if (_screenWidth == 0 || _screenHeight == 0) return;

    // Initialize BallPhysics if not already initialized
    if (_ballPhysics == null) {
      if (!_isCalibrated) {
        // Perform calibration on the first tick
        _calibrationOffset = Offset(_filteredAccelX, _filteredAccelY);
        _isCalibrated = true;

        _ballPhysics = BallPhysics(
          position: Offset.zero,
          velocity: Offset.zero,
          radius: _ballRadius,
          boundaryRadius: min(_screenWidth, _screenHeight) / 2 - _ballRadius,
          damping: 0.96, // Adjusted damping
          maxVelocity: 15.0, // Adjusted max velocity
          friction: 0.98, // Adjusted friction
        );

        developer.log('Calibration Offset: $_calibrationOffset');

        return; // Skip physics update on calibration tick
      }
    }

    if (_ballPhysics == null) return; // Safety check

    // Calculate adjusted acceleration by removing calibration offset
    Offset adjustedAccel = Offset(_filteredAccelX, _filteredAccelY) - _calibrationOffset;

    // Observe the adjustedAccel values and decide on inversion
    // Here, we assume that tilting forward increases adjustedAccel.dy
    // Adjust inversion based on your observations
    Offset acceleration = Offset(adjustedAccel.dx, -adjustedAccel.dy) * _sensitivity;

    // Apply acceleration to physics
    _ballPhysics!.applyAcceleration(acceleration);

    // Update physics
    _ballPhysics!.updatePosition();

    // Log position and velocity for debugging
    developer.log('Position: ${_ballPhysics!.position}, Velocity: ${_ballPhysics!.velocity}');

    // Trigger a rebuild for rendering
    setState(() {});
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
          // Ball using Transform for better performance
          Center(
            child: _ballPhysics == null
                ? Container(
              width: _ballRadius * 2,
              height: _ballRadius * 2,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            )
                : Transform.translate(
              offset: _ballPhysics!.position,
              child: Container(
                width: _ballRadius * 2,
                height: _ballRadius * 2,
                decoration: BoxDecoration(
                  color: _ballPhysics!.color, // Use the ball's current color
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
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
        ],
      ),
    );
  }
}
