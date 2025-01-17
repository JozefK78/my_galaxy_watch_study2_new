// lib/ball_physics.dart

import 'package:flutter/material.dart';

class BallPhysics {
  Offset position;
  Offset velocity;
  double radius; // Mutable to allow dynamic sizing
  final double boundaryRadius;
  final double damping;
  final double friction;
  final double mass; // Mass of the ball
  final double restitution; // Restitution coefficient for collisions
  Color color;

  BallPhysics({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.boundaryRadius,
    this.damping = 0.96,
    this.friction = 0.98,
    this.mass = 2.0, // Mass increased for more momentum
    this.restitution = 1.0, // Perfectly elastic collisions
    required this.color, // Assign color during initialization
  });

  /// Applies acceleration to the current velocity.
  void applyAcceleration(Offset acceleration) {
    velocity += acceleration;
  }

  /// Updates the ball's position based on its velocity.
  void updatePosition() {
    // Apply damping to simulate air resistance
    velocity *= damping;

    // Apply friction to simulate energy loss
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

      // Calculate velocity normal to the boundary
      double velocityNormal =
          velocity.dx * normal.dx + velocity.dy * normal.dy;

      // Reflect the velocity vector over the normal with restitution
      velocity = velocity - normal * ((1 + restitution) * velocityNormal);

      // Clamp the position to the boundary to prevent sticking
      position = normal * (boundaryRadius - radius);
    }
  }

  /// Resets the physics state (optional, for resetting the simulation)
  void reset() {
    velocity = Offset.zero;
    position = Offset.zero;
    radius = 15; // Reset to default radius
    // No color reset needed since collision coloring is removed
  }
}
