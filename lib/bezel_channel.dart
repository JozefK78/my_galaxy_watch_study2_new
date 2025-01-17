// lib/bezel_channel.dart
import 'package:flutter/services.dart';

class BezelChannel {
  static const EventChannel _eventChannel = EventChannel('bezel_rotation');

  // Stream to receive bezel rotation events
  static Stream<double>? _rotationStream;

  static Stream<double> get rotationStream {
    _rotationStream ??= _eventChannel.receiveBroadcastStream().map((event) => event as double);
    return _rotationStream!;
  }
}
