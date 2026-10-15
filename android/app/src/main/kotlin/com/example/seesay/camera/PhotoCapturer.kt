package com.example.seesay.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Size
import androidx.core.content.ContextCompat
import java.io.File

/**
 * Takes one JPEG with the phone's back camera through Camera2, without any screen.
 *
 * Unlike the Flutter camera plugin (bound to the Activity lifecycle) this works while the app is in
 * the background, as long as the foreground service runs with the `camera` type. A short preview
 * into a throw-away YUV reader lets auto-exposure settle before the still is taken.
 */
class PhotoCapturer(private val context: Context) {
    private val worker = Handler(HandlerThread("SeeSayCamera").apply { start() }.looper)
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var busy = false

    /** [done] is called on the main thread with the JPEG file or a readable error. */
    fun capture(done: (Result<File>) -> Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            done(Result.failure(IllegalStateException("Нет разрешения на камеру.")))
            return
        }
        if (busy) {
            done(Result.failure(IllegalStateException("Камера уже снимает.")))
            return
        }
        busy = true
        worker.post { Shot(done).start() }
    }

    private inner class Shot(private val done: (Result<File>) -> Unit) {
        private val manager = context.getSystemService(CameraManager::class.java)
        private var camera: CameraDevice? = null
        private var session: CameraCaptureSession? = null
        private var still: ImageReader? = null
        private var preview: ImageReader? = null
        private var orientation = 90
        private var previewStarted = 0L
        private var shotRequested = false
        private var finished = false
        private val timeout = Runnable { fail("Камера не ответила вовремя.") }

        @SuppressLint("MissingPermission")
        fun start() {
            worker.postDelayed(timeout, TIMEOUT_MS)
            try {
                val id = backCamera() ?: return fail("Камера не найдена.")
                val traits = manager.getCameraCharacteristics(id)
                val map = traits.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                    ?: return fail("Камера не поддерживается.")
                orientation = traits.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
                val jpeg = closestBelow(map.getOutputSizes(ImageFormat.JPEG), STILL_PIXELS)
                val small = closestBelow(map.getOutputSizes(ImageFormat.YUV_420_888), PREVIEW_PIXELS)
                still = ImageReader.newInstance(jpeg.width, jpeg.height, ImageFormat.JPEG, 1).apply {
                    setOnImageAvailableListener({ reader -> onJpeg(reader) }, worker)
                }
                preview = ImageReader.newInstance(small.width, small.height, ImageFormat.YUV_420_888, 2).apply {
                    setOnImageAvailableListener({ reader -> reader.acquireLatestImage()?.close() }, worker)
                }
                manager.openCamera(id, deviceCallback, worker)
            } catch (error: SecurityException) {
                fail("Нет разрешения на камеру.")
            } catch (error: CameraAccessException) {
                fail(describe(error))
            } catch (error: Exception) {
                Log.e(TAG, "camera start", error)
                fail("Камера недоступна.")
            }
        }

        private fun backCamera(): String? {
            val ids = manager.cameraIdList
            return ids.firstOrNull {
                manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_BACK
            } ?: ids.firstOrNull()
        }

        private val deviceCallback = object : CameraDevice.StateCallback() {
            override fun onOpened(device: CameraDevice) {
                camera = device
                if (finished) {
                    release()
                    return
                }
                openSession(device)
            }

            override fun onDisconnected(device: CameraDevice) {
                camera = device
                fail("Камеру забрало другое приложение.")
            }

            override fun onError(device: CameraDevice, error: Int) {
                camera = device
                fail(
                    when (error) {
                        ERROR_CAMERA_DISABLED -> BACKGROUND_BLOCKED
                        ERROR_CAMERA_IN_USE, ERROR_MAX_CAMERAS_IN_USE -> "Камера занята другим приложением."
                        else -> "Ошибка камеры ($error)."
                    },
                )
            }
        }

        @Suppress("DEPRECATION")
        private fun openSession(device: CameraDevice) {
            val targets = listOf(preview!!.surface, still!!.surface)
            try {
                device.createCaptureSession(
                    targets,
                    object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(created: CameraCaptureSession) {
                            session = created
                            if (finished) return
                            startPreview(device, created)
                        }

                        override fun onConfigureFailed(failed: CameraCaptureSession) {
                            fail("Не удалось настроить камеру.")
                        }
                    },
                    worker,
                )
            } catch (error: CameraAccessException) {
                fail(describe(error))
            }
        }

        private fun startPreview(device: CameraDevice, active: CameraCaptureSession) {
            try {
                val request = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                    addTarget(preview!!.surface)
                    set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                    set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                    set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                }.build()
                previewStarted = SystemClock.elapsedRealtime()
                active.setRepeatingRequest(request, warmup, worker)
            } catch (error: Exception) {
                fail("Камера недоступна.")
            }
        }

        /** Waits until auto-exposure settles (or a hard limit), then takes the still. */
        private val warmup = object : CameraCaptureSession.CaptureCallback() {
            override fun onCaptureCompleted(s: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
                if (shotRequested || finished) return
                val elapsed = SystemClock.elapsedRealtime() - previewStarted
                val ae = result.get(CaptureResult.CONTROL_AE_STATE)
                val settled = ae == null ||
                    ae == CaptureResult.CONTROL_AE_STATE_CONVERGED ||
                    ae == CaptureResult.CONTROL_AE_STATE_FLASH_REQUIRED ||
                    ae == CaptureResult.CONTROL_AE_STATE_LOCKED
                if ((settled && elapsed >= MIN_WARMUP_MS) || elapsed >= MAX_WARMUP_MS) takeStill(s)
            }
        }

        private fun takeStill(active: CameraCaptureSession) {
            shotRequested = true
            val device = camera ?: return fail("Камера недоступна.")
            try {
                val request = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                    addTarget(still!!.surface)
                    set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                    set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                    set(CaptureRequest.JPEG_ORIENTATION, orientation)
                    set(CaptureRequest.JPEG_QUALITY, JPEG_QUALITY)
                }.build()
                active.capture(request, null, worker)
            } catch (error: Exception) {
                fail("Не удалось сделать снимок.")
            }
        }

        private fun onJpeg(reader: ImageReader) {
            val image = reader.acquireLatestImage() ?: return
            val bytes = try {
                val buffer = image.planes[0].buffer
                ByteArray(buffer.remaining()).also { buffer.get(it) }
            } finally {
                image.close()
            }
            try {
                val file = File(context.cacheDir, "seesay_frame_${System.currentTimeMillis()}.jpg")
                file.writeBytes(bytes)
                finish(Result.success(file))
            } catch (error: Exception) {
                fail("Не удалось сохранить снимок.")
            }
        }

        private fun fail(message: String) {
            Log.w(TAG, "capture failed: $message")
            finish(Result.failure(IllegalStateException(message)))
        }

        private fun finish(outcome: Result<File>) {
            if (finished) return
            finished = true
            worker.removeCallbacks(timeout)
            release()
            busy = false
            main.post { done(outcome) }
        }

        private fun release() {
            runCatching { session?.close() }
            runCatching { camera?.close() }
            runCatching { still?.close() }
            runCatching { preview?.close() }
            session = null
            camera = null
        }

        private fun describe(error: CameraAccessException): String = when (error.reason) {
            CameraAccessException.CAMERA_DISABLED -> BACKGROUND_BLOCKED
            CameraAccessException.CAMERA_IN_USE, CameraAccessException.MAX_CAMERAS_IN_USE ->
                "Камера занята другим приложением."
            else -> "Камера недоступна."
        }
    }

    /** Largest size not above [pixels]; the smallest one when all are bigger. */
    private fun closestBelow(sizes: Array<Size>, pixels: Int): Size {
        val sorted = sizes.sortedBy { it.width.toLong() * it.height }
        return sorted.lastOrNull { it.width.toLong() * it.height <= pixels } ?: sorted.first()
    }

    companion object {
        private const val TAG = "PhotoCapturer"
        private const val TIMEOUT_MS = 8_000L
        private const val MIN_WARMUP_MS = 350L
        private const val MAX_WARMUP_MS = 1_500L
        private const val STILL_PIXELS = 1920 * 1080
        private const val PREVIEW_PIXELS = 640 * 480
        private const val JPEG_QUALITY: Byte = 85
        private const val BACKGROUND_BLOCKED =
            "Android не дал камеру в фоне. Откройте SeeSay и переподключите очки."
    }
}
