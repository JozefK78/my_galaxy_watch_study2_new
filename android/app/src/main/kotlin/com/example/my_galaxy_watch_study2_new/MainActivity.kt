// android/app/src/main/kotlin/com/example/your_app/MainActivity.kt
package com.example.your_app

import android.os.Bundle
import android.view.MotionEvent
import android.view.InputDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() {
    private val BEZEL_CHANNEL = "bezel_rotation"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        EventChannel(flutterEngine?.dartExecutor?.binaryMessenger, BEZEL_CHANNEL).setStreamHandler(
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

    private var bezelEventSink: EventChannel.EventSink? = null

    override fun onGenericMotionEvent(event: MotionEvent?): Boolean {
        if (event?.action == MotionEvent.ACTION_SCROLL &&
            event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER)) {
            val rotationDelta = -event.getAxisValue(MotionEvent.AXIS_SCROLL)
            bezelEventSink?.success(rotationDelta)
            return true
        }
        return super.onGenericMotionEvent(event)
    }
}
