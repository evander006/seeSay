package com.example.seesay.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.session.MediaSession
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.seesay.GlassesRuntime
import com.example.seesay.MainActivity
import com.example.seesay.ble.BleManager
import com.example.seesay.events.GlassesDeviceEvent
import com.example.seesay.events.GlassesEventStore
import com.example.seesay.events.MockGlassesEventSource

class GlassesForegroundService : Service(), BleManager.Listener {
    private var ble: BleManager? = null
    private var mediaSession: MediaSession? = null
    private var connected = false
    private val main = Handler(Looper.getMainLooper())
    private lateinit var store: GlassesEventStore
    private var mock: MockGlassesEventSource? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "onCreate")
        createChannel()
        store = GlassesEventStore(this)
        GlassesRuntime.ensureTts(this)
        ble = BleManager(applicationContext, this)
        mock = MockGlassesEventSource(
            schedule = { delay, action ->
                val runnable = Runnable { action() }
                main.postDelayed(runnable, delay)
                val cancel: () -> Unit = { main.removeCallbacks(runnable) }
                cancel
            },
            emit = ::accept,
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            promoteToForeground()
        } catch (error: Exception) {
            Log.e(TAG, "foreground start failed", error)
            GlassesRuntime.emitConnection(
                "error",
                "Мониторинг не запущен. Для очков нужно разрешение Bluetooth.",
                null,
            )
            stopSelf()
            return START_NOT_STICKY
        }
        Log.i(TAG, "onStartCommand ${intent?.action}")
        return try {
            dispatch(intent)
        } catch (error: Exception) {
            Log.e(TAG, "command failed ${intent?.action}", error)
            START_STICKY
        }
    }

    private fun dispatch(intent: Intent?): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                shutdown()
                return START_NOT_STICKY
            }
            ACTION_MONITOR_STOP -> {
                stopMonitoring()
                return START_STICKY
            }
            ACTION_MONITOR_START -> {
                beginMonitoring(intent.getStringExtra(EXTRA_ADDRESS))
                return START_STICKY
            }
            ACTION_SET_MOCK -> {
                val enabled = intent.getBooleanExtra(EXTRA_MOCK, true)
                store.mockMode = enabled
                if (store.monitoring && enabled) mock?.start() else mock?.stop()
                return START_STICKY
            }
            ACTION_TRIGGER -> {
                if (store.monitoring && store.mockMode) {
                    mock?.trigger(intent.getStringExtra(EXTRA_TYPE) ?: "TEXT_RECOGNIZED")
                }
                return START_STICKY
            }
        }
        startMediaSession()
        val address = intent?.getStringExtra(EXTRA_ADDRESS)
        ble?.connect(address)
        return START_STICKY
    }

    private fun promoteToForeground() {
        val notice = notification(connected)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notice)
            return
        }
        val type = foregroundType()
        Log.i(TAG, "startForeground type=$type mock=${store.mockMode} ble=${hasBlePermission()}")
        startForeground(NOTIFICATION_ID, notice, type)
    }

    private fun foregroundType(): Int {
        val bleGranted = hasBlePermission()
        if (Build.VERSION.SDK_INT >= 34 && (store.mockMode || !bleGranted)) {
            return ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        }
        return ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
    }

    private fun hasBlePermission(): Boolean {
        val connect = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.BLUETOOTH_CONNECT,
        ) == PackageManager.PERMISSION_GRANTED
        val scan = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.BLUETOOTH_SCAN,
        ) == PackageManager.PERMISSION_GRANTED
        return connect || scan
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.i(TAG, "onDestroy")
        mock?.stop()
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        ble?.release()
        ble = null
        super.onDestroy()
    }

    override fun onConnection(state: String, message: String?, address: String?) {
        connected = state == "connected"
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification(connected))
        GlassesRuntime.emitConnection(state, message, address)
    }

    override fun onPacket(bytes: ByteArray) {
        GlassesRuntime.emitPacket(bytes)
    }

    override fun onBattery(level: Int) {
        GlassesRuntime.emitBattery(level)
    }

    private fun beginMonitoring(address: String?) {
        store.monitoring = true
        startMediaSession()
        if (store.mockMode) {
            mock?.start()
            Log.i(TAG, "mock monitoring started")
            Log.i("MockGlassesEventSource", "started")
        } else {
            mock?.stop()
            ble?.connect(address)
            Log.i(TAG, "ble monitoring started")
        }
    }

    private fun stopMonitoring() {
        mock?.stop()
        store.monitoring = false
        Log.i(TAG, "monitoring stopped")
        Log.i("MockGlassesEventSource", "stopped")
        if (!connected) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun accept(event: GlassesDeviceEvent) {
        if (!store.save(event)) return
        Log.i(TAG, "event ${event.type} ${event.eventId}")
        GlassesRuntime.emit(event.toMap())
        if (GlassesRuntime.eventSink == null) {
            val phrase = when (event.type) {
                "TEXT_RECOGNIZED" -> event.text?.let { "На табличке написано: $it" }
                "SCENE_ANALYSIS_READY" -> event.text
                "GLASSES_CONNECTED" -> "Очки подключены."
                "DEVICE_ERROR" -> event.error
                else -> null
            }
            if (!phrase.isNullOrBlank()) GlassesRuntime.tts?.speakLocally(phrase)
        }
    }

    private fun shutdown() {
        mock?.stop()
        store.monitoring = false
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
            setFlags(
                MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS,
            )
            isActive = true
        }
    }

    private fun createChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SeeSay",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Подключение очков SeeSay"
        manager.createNotificationChannel(channel)
    }

    private fun notification(isConnected: Boolean): Notification {
        val text = if (isConnected) {
            "SeeSay: очки подключены"
        } else {
            "SeeSay: выполняется подключение"
        }
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
        private const val ACTION_STOP = "com.example.seesay.STOP_GLASSES"
        private const val ACTION_MONITOR_START = "com.example.seesay.MONITOR_START"
        private const val ACTION_MONITOR_STOP = "com.example.seesay.MONITOR_STOP"
        private const val ACTION_SET_MOCK = "com.example.seesay.SET_MOCK"
        private const val ACTION_TRIGGER = "com.example.seesay.TRIGGER_MOCK"
        private const val EXTRA_ADDRESS = "deviceAddress"
        private const val EXTRA_MOCK = "mock"
        private const val EXTRA_TYPE = "type"

        fun start(context: Context, deviceAddress: String?) {
            val intent = Intent(context, GlassesForegroundService::class.java)
            if (!deviceAddress.isNullOrBlank()) {
                intent.putExtra(EXTRA_ADDRESS, deviceAddress)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, GlassesForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        fun startMonitoring(context: Context) {
            val store = GlassesEventStore(context)
            if (!store.mockMode && !hasBlePermission(context)) {
                throw IllegalStateException(
                    "Для мониторинга очков нужно разрешение Bluetooth.",
                )
            }
            val intent = Intent(context, GlassesForegroundService::class.java).apply {
                action = ACTION_MONITOR_START
            }
            ContextCompat.startForegroundService(context, intent)
        }

        private fun hasBlePermission(context: Context): Boolean {
            val connect = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT,
            ) == PackageManager.PERMISSION_GRANTED
            val scan = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_SCAN,
            ) == PackageManager.PERMISSION_GRANTED
            return connect || scan
        }

        fun stopMonitoring(context: Context) {
            val intent = Intent(context, GlassesForegroundService::class.java).apply {
                action = ACTION_MONITOR_STOP
            }
            context.startService(intent)
        }

        fun setMock(context: Context, enabled: Boolean) {
            val store = com.example.seesay.events.GlassesEventStore(context)
            store.mockMode = enabled
            if (!store.monitoring) return
            val intent = Intent(context, GlassesForegroundService::class.java).apply {
                action = ACTION_SET_MOCK
                putExtra(EXTRA_MOCK, enabled)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun trigger(context: Context, type: String) {
            val intent = Intent(context, GlassesForegroundService::class.java).apply {
                action = ACTION_TRIGGER
                putExtra(EXTRA_TYPE, type)
            }
            ContextCompat.startForegroundService(context, intent)
        }
    }
}

private fun Intent.keyEvent(): KeyEvent? {
    return if (android.os.Build.VERSION.SDK_INT >= 33) {
        getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
    } else {
        @Suppress("DEPRECATION")
        getParcelableExtra(Intent.EXTRA_KEY_EVENT)
    }
}
