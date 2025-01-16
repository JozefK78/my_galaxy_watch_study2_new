// lib/ball_physics.dart

import 'dart:math';
import 'package:flutter/material.dart';

class BallPhysics {
  Offset position;
  Offset velocity;
  final double radius;
  final double boundaryRadius;
  final double damping;
  final double maxVelocity;
  final double friction;
  Color color;

  BallPhysics({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.boundaryRadius,
    this.damping = 0.96, // Adjusted damping
    this.maxVelocity = 15.0, // Adjusted max velocity
    this.friction = 0.98, // Adjusted friction
    this.color = Colors.blue, // Initial color
  });

  /// Applies acceleration to the current velocity.
  void applyAcceleration(Offset acceleration) {
    velocity += acceleration;

    // Cap the velocity to the maximum allowed
    if (velocity.distance > maxVelocity) {
      velocity = velocity / velocity.distance * maxVelocity;
    }
  }

  /// Updates the ball's position based on its velocity.
  void updatePosition() {
    // Apply damping to simulate friction or air resistance
    velocity *= damping;

    // Apply friction to further reduce velocity
    velocity *= friction;

    // Update position with current velocity
    position += velocity;

    // Handle collision with boundary
    _handleBoundaryCollision();
  }

  /// Handles collision with the circular boundary and reflects velocity accordingly.
  void _handleBoundaryCollision() {
    double distanceFromCenter = position.distance;

    if (distanceFromCenter + radius >= boundaryRadius) {
      // Calculate the normal vector at the point of collision
      Offset normal = position / distanceFromCenter;

      // Reflect the velocity vector over the normal
      velocity = _reflect(velocity, normal);

      // Clamp the position to the boundary to prevent sticking
      position = normal * (boundaryRadius - radius);

      // Apply additional damping upon collision to simulate energy loss
      velocity *= damping;

      // Change color to indicate collision
      color = Colors.red;

      // Reset color after a short duration
      _resetColor();
    }
  }

  /// Reflects a vector over a given normal.
  Offset _reflect(Offset vector, Offset normal) {
    double dotProduct = vector.dx * normal.dx + vector.dy * normal.dy;
    return vector - normal * (2 * dotProduct);
  }

  /// Resets the ball's color back to blue after collision
  void _resetColor() {
    Future.delayed(Duration(milliseconds: 100), () {
      color = Colors.blue;
    });
  }

  /// Resets the physics state (optional, for resetting the simulation)
  void reset() {
    velocity = Offset.zero;
    position = Offset.zero;
    color = Colors.blue;
  }
}
