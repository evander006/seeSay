package com.example.seesay.service

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.session.MediaSession
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.seesay.GlassesRuntime
import com.example.seesay.MainActivity
import com.example.seesay.DiagLog
import com.example.seesay.ble.BleManager
import com.example.seesay.ble.GlassesSession

/**
 * Keeps the BLE link to the glasses and the app process alive while the screen is off or the app
 * is closed. Runs with the `camera` type too, so the Dart pipeline may take photos in background.
 */
class GlassesForegroundService : Service(), BleManager.Listener {
    private var ble: BleManager? = null
    private var session: GlassesSession? = null
    private var mediaSession: MediaSession? = null
    private var connected = false
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        GlassesRuntime.ensureTts(this)
        DiagLog.init(this)
        val manager = BleManager(applicationContext, this)
        ble = manager
        session = GlassesSession(applicationContext) { cmd, payload -> manager.send(cmd, payload) }
        GlassesRuntime.session = session
        wakeLock = getSystemService(PowerManager::class.java)
            ?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SeeSay:glassesAction")
            ?.apply { setReferenceCounted(false) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            promoteToForeground()
        } catch (error: Exception) {
            Log.e(TAG, "foreground start failed", error)
            GlassesRuntime.emitConnection("error", "Для очков нужно разрешение Bluetooth.", null)
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_STOP) {
            shutdown()
            return START_NOT_STICKY
        }
        startMediaSession()
        ble?.connect(intent?.getStringExtra(EXTRA_ADDRESS))
        return START_STICKY
    }

    private fun promoteToForeground() {
        val notice = notification(connected)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notice)
            return
        }
        val base = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
        var withCamera = if (granted(Manifest.permission.CAMERA)) base or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA else base
        // Location type: «где я» and routes need GPS while the screen is off.
        if (granted(Manifest.permission.ACCESS_FINE_LOCATION) || granted(Manifest.permission.ACCESS_COARSE_LOCATION)) {
            withCamera = withCamera or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
        }
        try {
            startForeground(NOTIFICATION_ID, notice, withCamera)
        } catch (error: SecurityException) {
            // Camera type is refused when started from background; the BLE link still matters.
            Log.w(TAG, "camera foreground type refused", error)
            startForeground(NOTIFICATION_ID, notice, base)
        }
    }

    private fun granted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        ble?.release()
        ble = null
        session?.release()
        if (GlassesRuntime.session === session) GlassesRuntime.session = null
        session = null
        wakeLock?.takeIf { it.isHeld }?.release()
        super.onDestroy()
    }

    override fun onConnection(state: String, message: String?, address: String?, detail: String?) {
        val now = state == "connected"
        if (now != connected) {
            connected = now
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(connected))
        }
        if (!now) session?.onLinkLost()
        DiagLog.i(TAG, "connection $state ${message ?: ""} ${detail ?: ""}".trim())
        GlassesRuntime.emitConnection(state, message, address, detail)
    }

    override fun onPacket(bytes: ByteArray) {
        keepAwake()
        session?.onBytes(bytes)
    }

    override fun onReady() {
        session?.onLinkReady()
    }

    override fun onBattery(level: Int) {
        GlassesRuntime.emitBattery(level)
    }

    /** A button press starts photo → upload → speech; keep the CPU up even with the screen off. */
    private fun keepAwake() {
        wakeLock?.acquire(WAKE_MS)
    }

    private fun shutdown() {
        connected = false
        ble?.disconnect()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startMediaSession() {
        if (mediaSession != null) return
        mediaSession = MediaSession(this, "SeeSay").apply {
            setCallback(
                object : MediaSession.Callback() {
                    override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                        val keyEvent = mediaButtonIntent.keyEvent() ?: return false
                        if (keyEvent.action == KeyEvent.ACTION_DOWN) {
                            keepAwake()
                            DiagLog.i(TAG, "media key ${KeyEvent.keyCodeToString(keyEvent.keyCode)}")
                            GlassesRuntime.emitMedia(keyEvent.keyCode)
                        }
                        val mediaKey = keyEvent.keyCode == KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE ||
                            keyEvent.keyCode == KeyEvent.KEYCODE_HEADSETHOOK ||
                            keyEvent.keyCode == KeyEvent.KEYCODE_MEDIA_PLAY ||
                            keyEvent.keyCode == KeyEvent.KEYCODE_MEDIA_PAUSE
                        return if (mediaKey) true else super.onMediaButtonEvent(mediaButtonIntent)
                    }
                },
            )
            @Suppress("DEPRECATION")
            setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
            isActive = true
        }
    }

    private fun createChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "SeeSay", NotificationManager.IMPORTANCE_LOW)
        channel.description = "Подключение очков SeeSay"
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun notification(isConnected: Boolean): Notification {
        val text = if (isConnected) "Очки подключены, SeeSay работает в фоне" else "Подключаю очки…"
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SeeSay")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .setContentIntent(open)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    companion object {
        private const val TAG = "GlassesForegroundService"
        private const val CHANNEL_ID = "aimb_s2_glasses"
        private const val NOTIFICATION_ID = 42
        private const val WAKE_MS = 30_000L
        private const val ACTION_STOP = "com.example.seesay.STOP_GLASSES"
        private const val EXTRA_ADDRESS = "deviceAddress"

        fun start(context: Context, deviceAddress: String?) {
            val intent = Intent(context, GlassesForegroundService::class.java)
            if (!deviceAddress.isNullOrBlank()) intent.putExtra(EXTRA_ADDRESS, deviceAddress)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, GlassesForegroundService::class.java).apply { action = ACTION_STOP }
            context.startService(intent)
        }
    }
}

private fun Intent.keyEvent(): KeyEvent? {
    return if (Build.VERSION.SDK_INT >= 33) {
        getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
    } else {
        @Suppress("DEPRECATION")
        getParcelableExtra(Intent.EXTRA_KEY_EVENT)
    }
}
