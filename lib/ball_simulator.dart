// lib/ball_simulator.dart

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'ball_physics.dart'; // Import the BallPhysics class
import 'dart:developer' as developer;
import 'bezel_channel.dart'; // Import the BezelChannel class

class BallSimulator extends StatefulWidget {
  @override
  _BallSimulatorState createState() => _BallSimulatorState();
}

class _BallSimulatorState extends State<BallSimulator>
    with SingleTickerProviderStateMixin {
  List<BallPhysics> _balls = []; // List to hold multiple balls
  late double _screenWidth;
  late double _screenHeight;
  final double _ballRadius = 15;

  // Sensitivity factor to control acceleration response
  final double _sensitivity = 0.15; // Updated sensitivity

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

  // Variables for touch interaction
  BallPhysics? _grabbedBall;
  Offset? _lastTouchPosition;
  DateTime? _lastTouchTime;

  // Maximum and minimum number of balls
  final int _maxBalls = 20;
  final int _minBalls = 1;

  // Total area constraint (1/3 of screen area)
  static const double _maxTotalAreaRatio = 1 / 3;

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
        _filteredAccelX =
            _lowPassFilter(_filteredAccelX, event.x, _filterAlpha);
        _filteredAccelY =
            _lowPassFilter(_filteredAccelY, event.y, _filterAlpha);
      });
    });

    // Initialize balls after first frame
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _initializeBalls();
    });

    // Listen to bezel rotation
    BezelChannel.rotationStream.listen((rotationDelta) {
      _handleBezelRotation(rotationDelta);
    });
  }

  /// Initializes balls based on the current number of balls
  void _initializeBalls() {
    // Ensure screen dimensions are available
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    // Calculate boundary radius
    double boundaryRadius = min(_screenWidth, _screenHeight) / 2 - _ballRadius;

    // Initialize 10 balls with random positions and colors
    List<BallPhysics> newBalls = [];
    Random random = Random();

    for (int i = 0; i < 10; i++) {
      // Generate random angle and distance within boundary
      double angle = random.nextDouble() * 2 * pi;
      double distance = random.nextDouble() * boundaryRadius;

      // Calculate position
      double posX = distance * cos(angle);
      double posY = distance * sin(angle);
      Offset position = Offset(posX, posY);

      // Assign random color
      Color color = Colors.primaries[random.nextInt(Colors.primaries.length)];

      // Create BallPhysics instance
      BallPhysics ball = BallPhysics(
        position: position,
        velocity: Offset.zero,
        radius: _ballRadius,
        boundaryRadius: boundaryRadius,
        damping: 0.96,
        friction: 0.98,
        mass: 2.0, // Higher mass
        restitution: 1.0, // Perfectly elastic
        color: color,
      );

      newBalls.add(ball);
    }

    setState(() {
      _balls = newBalls;
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

    // Corrected Acceleration Inversion
    // Invert X-axis to align tilting left with positive screen X movement
    Offset acceleration = Offset(-adjustedAccel.dx, adjustedAccel.dy) * _sensitivity;

    // Apply acceleration to each ball if it's not grabbed
    for (var ball in _balls) {
      if (ball != _grabbedBall) {
        ball.applyAcceleration(acceleration);
        ball.updatePosition();
      }
    }

    // Handle ball-ball collisions
    _handleBallCollisions();

    // Log position and velocity for debugging
    for (int i = 0; i < _balls.length; i++) {
      developer.log(
          'Ball $i - Position: ${_balls[i].position}, Velocity: ${_balls[i].velocity}');
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

        if (distance < minDistance && distance > 0) { // Avoid division by zero
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
        }
      }
    }
  }

  /// Handles bezel rotation to adjust the number of balls
  void _handleBezelRotation(double rotationDelta) {
    // Define a threshold to determine significant rotation
    const double rotationThreshold = 0.1;

    if (rotationDelta.abs() < rotationThreshold) return;

    setState(() {
      if (rotationDelta > 0) {
        // Rotate clockwise: Increase the number of balls
        if (_balls.length < _maxBalls) {
          _addBall();
          _adjustBallSizes();
        }
      } else {
        // Rotate counter-clockwise: Decrease the number of balls
        if (_balls.length > _minBalls) {
          _removeBall();
          _adjustBallSizes();
        }
      }
    });
  }

  /// Adjusts ball sizes based on the number of balls to ensure total area <= 1/3 of screen area
  void _adjustBallSizes() {
    // Calculate total available area
    double screenArea = _screenWidth * _screenHeight;
    double maxTotalArea = screenArea * _maxTotalAreaRatio;

    // Calculate current total area
    double currentTotalArea = _balls.fold(
        0, (sum, ball) => sum + pi * pow(ball.radius, 2));

    // If current total area exceeds max, scale down the radii
    if (currentTotalArea > maxTotalArea) {
      double scalingFactor = sqrt(maxTotalArea / currentTotalArea);
      for (var ball in _balls) {
        ball.radius *= scalingFactor;
      }
    } else {
      // If total area is less, reset to default radius
      for (var ball in _balls) {
        ball.radius = _ballRadius;
      }
    }
  }

  /// Handles touch interactions
  void _handlePanStart(DragStartDetails details) {
    // Convert global touch position to center-relative position
    Offset touchPosition =
        details.localPosition - Offset(_screenWidth / 2, _screenHeight / 2);

    // Find the topmost ball that contains the touch point
    for (var ball in _balls.reversed) {
      if ((ball.position - touchPosition).distance <= ball.radius) {
        _grabbedBall = ball;
        _lastTouchPosition = touchPosition;
        _lastTouchTime = DateTime.now();
        // Optionally, set ball's velocity to zero while dragging
        ball.velocity = Offset.zero;
        break;
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_grabbedBall != null) {
      // Convert global touch position to center-relative position
      Offset touchPosition =
          details.localPosition - Offset(_screenWidth / 2, _screenHeight / 2);

      // Calculate movement delta
      Offset delta = touchPosition - _lastTouchPosition!;
      Duration deltaTime = DateTime.now().difference(_lastTouchTime!);

      // Update ball's position
      setState(() {
        _grabbedBall!.position = touchPosition;
      });

      // Update last touch position and time
      _lastTouchPosition = touchPosition;
      _lastTouchTime = DateTime.now();
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_grabbedBall != null && _lastTouchTime != null) {
      // Calculate velocity based on the last movement
      Duration deltaTime = DateTime.now().difference(_lastTouchTime!);
      if (deltaTime.inMilliseconds > 0) {
        Offset velocity =
            (_grabbedBall!.position - _lastTouchPosition!) /
                deltaTime.inMilliseconds *
                1000; // pixels per second
        setState(() {
          _grabbedBall!.velocity = velocity;
        });
      }
    }
    _grabbedBall = null;
    _lastTouchPosition = null;
    _lastTouchTime = null;
  }

  /// Low-pass filter to smooth accelerometer data
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
      body: GestureDetector(
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Stack(
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
                      color: ball.color, // Use the ball's assigned color
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
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
                          style:
                          TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        Text(
                          'Calibrated Accel Y: ${(Offset(_filteredAccelX, _filteredAccelY) - _calibrationOffset).dy.toStringAsFixed(2)}',
                          style:
                          TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Move reset button to (20, 20)
            Positioned(
              top: 20,
              left: 20,
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
      ),
    );
  }
}
