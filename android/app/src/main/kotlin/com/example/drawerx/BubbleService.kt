package com.example.drawerx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.ImageView
import kotlin.math.abs

class BubbleService : Service() {

    private var windowManager: WindowManager? = null
    private var bubbleView: ImageView? = null

    override fun onCreate() {
        super.onCreate()

        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        isRunning = true

        startForeground(
            NOTIFICATION_ID,
            createNotification()
        )

        showBubble()
    }

    private fun showBubble() {

        if (bubbleView != null) {
            return
        }

        val manager =
            getSystemService(WINDOW_SERVICE)
                as WindowManager

        windowManager = manager

        val bubble = ImageView(this)

        bubble.setImageResource(
            com.example.drawerx.R.drawable.drawerx_bubble
        )

        bubble.scaleType =
            ImageView.ScaleType.CENTER_CROP

        bubble.setBackground(
            createBubbleBackground()
        )

        bubble.clipToOutline = true

        bubble.elevation = 12f

val bubbleSize = 90
val edgeMargin = 12

val params = WindowManager.LayoutParams(
    bubbleSize,
    bubbleSize,

            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.O
            ) {
                WindowManager.LayoutParams
                    .TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams
                    .TYPE_PHONE
            },

            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,

            PixelFormat.TRANSLUCENT
        )

        params.gravity =
            Gravity.TOP or Gravity.START

        params.x = 20
        params.y = 300

        var downX = 0f
        var downY = 0f

        var startX = 0
        var startY = 0

        bubble.setOnTouchListener { view, event ->

            when (event.actionMasked) {

                MotionEvent.ACTION_DOWN -> {

                    downX = event.rawX
                    downY = event.rawY

                    startX = params.x
                    startY = params.y

                    true
                }

                MotionEvent.ACTION_MOVE -> {

    val screenWidth =
        resources.displayMetrics.widthPixels

    val screenHeight =
        resources.displayMetrics.heightPixels

    val newX =
        startX +
            (event.rawX - downX).toInt()

    val newY =
        startY +
            (event.rawY - downY).toInt()

    params.x = newX.coerceIn(
        edgeMargin,
        screenWidth - bubbleSize - edgeMargin
    )

    params.y = newY.coerceIn(
        edgeMargin,
        screenHeight - bubbleSize - edgeMargin
    )

    try {
        manager.updateViewLayout(
            view,
            params
        )
    } catch (_: Exception) {
    }

    true
}

MotionEvent.ACTION_UP -> {

    val movedX =
        abs(event.rawX - downX)

    val movedY =
        abs(event.rawY - downY)

    // Tap biasa → buka DrawerX
    if (
        movedX < 15 &&
        movedY < 15
    ) {
        openDrawerX()
        return@setOnTouchListener true
    }

    // Kalau digeser → snap ke kiri atau kanan
    val screenWidth =
        resources.displayMetrics.widthPixels

    val centerX =
        params.x + (bubbleSize / 2)

    params.x =
        if (centerX < screenWidth / 2) {
            edgeMargin
        } else {
            screenWidth -
                bubbleSize -
                edgeMargin
        }

    try {
        manager.updateViewLayout(
            view,
            params
        )
    } catch (_: Exception) {
    }

    true
}

                else -> true
            }
        }

        try {

            manager.addView(
                bubble,
                params
            )

            bubbleView = bubble

        } catch (_: Exception) {

            bubbleView = null
            isRunning = false

            stopSelf()
        }
    }

    private fun createBubbleBackground():
        GradientDrawable {

        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.TRANSPARENT)
        }
    }

    private fun openDrawerX() {

        val intent =
            packageManager.getLaunchIntentForPackage(
                packageName
            )

        if (intent != null) {

            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            )

            startActivity(intent)
        }
    }

    private fun createNotification(): Notification {

        val channelId =
            "drawerx_bubble"

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            val channel =
                NotificationChannel(
                    channelId,
                    "DrawerX Bubble",
                    NotificationManager
                        .IMPORTANCE_LOW
                )

            val manager =
                getSystemService(
                    NotificationManager::class.java
                )

            manager.createNotificationChannel(
                channel
            )
        }

        return if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            Notification.Builder(
                this,
                channelId
            )
                .setContentTitle("DrawerX")
                .setContentText("Bubble aktif")
                .setSmallIcon(
                    android.R.drawable.ic_menu_edit
                )
                .setOngoing(true)
                .build()

        } else {

            Notification.Builder(this)
                .setContentTitle("DrawerX")
                .setContentText("Bubble aktif")
                .setSmallIcon(
                    android.R.drawable.ic_menu_edit
                )
                .setOngoing(true)
                .build()
        }
    }

    override fun onDestroy() {

        isRunning = false

        bubbleView?.let { view ->

            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {
            }
        }

        bubbleView = null
        windowManager = null

        super.onDestroy()
    }

    override fun onBind(
        intent: Intent?
    ): IBinder? {
        return null
    }

    companion object {

        private const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning: Boolean = false
            private set
    }
}