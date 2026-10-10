package com.example.seesay.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import java.util.UUID

class BleManager(
    private val context: Context,
    private val listener: Listener,
) {
    interface Listener {
        fun onConnection(state: String, message: String?, address: String?)
        fun onPacket(bytes: ByteArray)
        fun onBattery(level: Int)
    }

    private val main = Handler(Looper.getMainLooper())
    private var gatt: BluetoothGatt? = null
    private var scannerCallback: ScanCallback? = null
    private var userDisconnect = false
    private var attempts = 0
    private var targetAddress: String? = null

    fun connect(preferredAddress: String?, resetAttempts: Boolean = true) {
        if (resetAttempts) attempts = 0
        userDisconnect = false
        main.removeCallbacksAndMessages(null)
        targetAddress = preferredAddress
        val adapter = adapter()
        if (adapter == null || !adapter.isEnabled) {
            listener.onConnection("error", "Bluetooth недоступен.", null)
            return
        }
        if (!hasBlePermission()) {
            listener.onConnection("error", "Нет необходимого разрешения.", null)
            return
        }
        listener.onConnection("connecting", null, preferredAddress)
        if (!preferredAddress.isNullOrBlank()) {
            connectDevice(adapter.getRemoteDevice(preferredAddress))
        } else {
            startScan(adapter)
        }
    }

    fun disconnect() {
        userDisconnect = true
        main.removeCallbacksAndMessages(null)
        stopScan()
        closeGatt()
        attempts = 0
        listener.onConnection("disconnected", null, null)
    }

    fun release() {
        userDisconnect = true
        main.removeCallbacksAndMessages(null)
        stopScan()
        closeGatt()
    }

    private fun adapter(): BluetoothAdapter? {
        return context.getSystemService(BluetoothManager::class.java)?.adapter
    }

    private fun hasBlePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            granted(android.Manifest.permission.BLUETOOTH_SCAN) &&
                granted(android.Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            granted(android.Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun granted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission")
    private fun startScan(adapter: BluetoothAdapter) {
        stopScan()
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            listener.onConnection("error", "Bluetooth недоступен.", null)
            return
        }
        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                stopScan()
                connectDevice(result.device)
            }

            override fun onScanFailed(errorCode: Int) {
                listener.onConnection("error", "Не удалось подключиться к очкам.", null)
            }
        }
        scannerCallback = callback
        scanner.startScan(listOf(filter), settings, callback)
        main.postDelayed({
            if (scannerCallback === callback && gatt == null) {
                stopScan()
                scheduleReconnect()
            }
        }, 15_000)
    }

    @SuppressLint("MissingPermission")
    private fun stopScan() {
        val callback = scannerCallback ?: return
        scannerCallback = null
        adapter()?.bluetoothLeScanner?.stopScan(callback)
    }

    @SuppressLint("MissingPermission")
    private fun connectDevice(device: BluetoothDevice) {
        closeGatt()
        targetAddress = device.address
        gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
    }

    private val callback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (userDisconnect) return
            if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                gatt.discoverServices()
                return
            }
            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                if (this@BleManager.gatt != gatt) return
                closeGatt()
                scheduleReconnect()
            }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                scheduleReconnect()
                return
            }
            val service = gatt.getService(SERVICE_UUID)
            val notify = service?.getCharacteristic(NOTIFY_UUID)
            if (service == null || notify == null) {
                listener.onConnection("error", "Сервис очков не найден.", gatt.device.address)
                return
            }
            gatt.setCharacteristicNotification(notify, true)
            val descriptor = notify.getDescriptor(CCCD_UUID)
            if (descriptor == null) {
                listener.onConnection("error", "Сервис очков не найден.", gatt.device.address)
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            } else {
                @Suppress("DEPRECATION")
                descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                @Suppress("DEPRECATION")
                gatt.writeDescriptor(descriptor)
            }
            readBattery(gatt)
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            if (descriptor.uuid == CCCD_UUID && status == BluetoothGatt.GATT_SUCCESS) {
                attempts = 0
                listener.onConnection("connected", null, gatt.device.address)
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            if (characteristic.uuid == NOTIFY_UUID) listener.onPacket(value)
            if (characteristic.uuid == BATTERY_LEVEL) listener.onBattery(value.firstOrNull()?.toInt()?.and(0xFF) ?: return)
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return
            @Suppress("DEPRECATION")
            val value = characteristic.value ?: return
            onCharacteristicChanged(gatt, characteristic, value)
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return
            if (status == BluetoothGatt.GATT_SUCCESS && characteristic.uuid == BATTERY_LEVEL) {
                @Suppress("DEPRECATION")
                val value = characteristic.value ?: return
                listener.onBattery(value.firstOrNull()?.toInt()?.and(0xFF) ?: return)
            }
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int,
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS && characteristic.uuid == BATTERY_LEVEL && value.isNotEmpty()) {
                listener.onBattery(value[0].toInt() and 0xFF)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun readBattery(gatt: BluetoothGatt) {
        val battery = gatt.getService(BATTERY_SERVICE)?.getCharacteristic(BATTERY_LEVEL) ?: return
        gatt.readCharacteristic(battery)
    }

    private fun scheduleReconnect() {
        if (userDisconnect) return
        if (attempts >= 4) {
            listener.onConnection("error", "Не удалось подключиться к очкам.", targetAddress)
            return
        }
        val delay = 1000L shl attempts
        attempts += 1
        listener.onConnection("reconnecting", null, targetAddress)
        main.postDelayed({
            if (!userDisconnect) connect(targetAddress, resetAttempts = false)
        }, delay.coerceAtMost(8000L))
    }

    @SuppressLint("MissingPermission")
    private fun closeGatt() {
        val current = gatt
        gatt = null
        current?.close()
    }

    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("0000fa00-0000-1000-8000-00805f9b34fb")
        val NOTIFY_UUID: UUID = UUID.fromString("0000ea01-0000-1000-8000-00805f9b34fb")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        val BATTERY_SERVICE: UUID = UUID.fromString("0000180f-0000-1000-8000-00805f9b34fb")
        val BATTERY_LEVEL: UUID = UUID.fromString("00002a19-0000-1000-8000-00805f9b34fb")
    }
}
