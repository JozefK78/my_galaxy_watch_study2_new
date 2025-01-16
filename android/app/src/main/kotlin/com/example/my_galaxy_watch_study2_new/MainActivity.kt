package com.example.my_galaxy_watch_study2_new

import android.os.Bundle
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val BEZEL_CHANNEL = "bezel_rotation"
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        EventChannel(flutterEngine?.dartExecutor?.binaryMessenger, BEZEL_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    override fun onGenericMotionEvent(event: MotionEvent?): Boolean {
        if (event?.action == MotionEvent.ACTION_SCROLL &&
            event.isFromSource(android.view.InputDevice.SOURCE_ROTARY_ENCODER)) {
            val delta = event.getAxisValue(MotionEvent.AXIS_SCROLL)
            eventSink?.success(delta)
            return true
        }
        return super.onGenericMotionEvent(event)
    }
}
