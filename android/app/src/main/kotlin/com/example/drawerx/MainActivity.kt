package com.example.drawerx

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "drawerx/bubble"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "requestOverlayPermission" -> {

                    if (!Settings.canDrawOverlays(this)) {

                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION
                        )

                        intent.data =
                            android.net.Uri.parse(
                                "package:$packageName"
                            )

                        startActivity(intent)

                        result.success(false)

                    } else {
                        result.success(true)
                    }
                }

                "startBubble" -> {

                    if (!Settings.canDrawOverlays(this)) {

                        result.error(
                            "NO_PERMISSION",
                            "Overlay permission belum diberikan",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    val intent = Intent(
                        this,
                        BubbleService::class.java
                    )

                    if (
                        android.os.Build.VERSION.SDK_INT >=
                        android.os.Build.VERSION_CODES.O
                    ) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }

                    result.success(true)
                }

                "stopBubble" -> {

                    val intent = Intent(
                        this,
                        BubbleService::class.java
                    )

                    stopService(intent)

                    result.success(true)
                }

                "isBubbleRunning" -> {

                    result.success(
                        BubbleService.isRunning
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}