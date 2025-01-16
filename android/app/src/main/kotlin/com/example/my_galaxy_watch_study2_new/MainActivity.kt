// android/app/src/main/kotlin/com/example/your_app/MainActivity.kt
package com.example.my_galaxy_watch_study2_new

import android.os.Bundle
import android.view.MotionEvent
import android.view.InputDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val BEZEL_CHANNEL = "bezel_rotation"
    private var bezelEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BEZEL_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bezelEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    bezelEventSink = null
                }
            }
        )
    }

    override fun onGenericMotionEvent(event: MotionEvent?): Boolean {
        if (event?.action == MotionEvent.ACTION_SCROLL &&
            event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER)) {
            val rotationDelta = -event.getAxisValue(MotionEvent.AXIS_SCROLL)
            bezelEventSink?.success(rotationDelta.toDouble())
            return true
        }
        return super.onGenericMotionEvent(event)
    }

    override fun dispatchTouchEvent(event: MotionEvent?): Boolean {
        if (event != null) {
            // Forward touch events to Flutter
            super.dispatchTouchEvent(event)
            // Return true to indicate the event has been consumed
            return true
        }
        return super.dispatchTouchEvent(event)
    }
}
