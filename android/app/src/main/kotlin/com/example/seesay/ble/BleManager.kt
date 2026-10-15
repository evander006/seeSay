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
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.example.seesay.DiagLog
import java.util.UUID

/**
 * Finds the AIMB S2 glasses and keeps the BLE link to their FA00 service.
 *
 * Glasses that are already paired and playing as a Bluetooth headset usually do not advertise
 * FA00, so a scan filtered by that service never sees them. Discovery therefore gathers
 * candidates from several sources and checks each one for FA00 over GATT, in this order:
 * saved address → devices already linked over BLE (e.g. by the vendor app) → advertises FA00 →
 * BLE twin of the connected headset (same name or address prefix) → the headset itself over LE →
 * glasses-like names nearby or among paired devices.
 *
 * All state lives on the main thread; GATT and scan callbacks are re-posted there.
 */
class BleManager(
    private val context: Context,
    private val listener: Listener,
) {
    interface Listener {
        /** [detail] is a human-readable progress or failure report for the screen, not for speech. */
        fun onConnection(state: String, message: String?, address: String?, detail: String? = null)
        fun onPacket(bytes: ByteArray)
        fun onBattery(level: Int)

        /** Notifications are on and the MTU is set: commands may be sent now. */
        fun onReady()
    }

    private class Candidate(val device: BluetoothDevice, val label: String)

    private class Seen(val device: BluetoothDevice, val name: String, val rssi: Int)

    private val main = Handler(Looper.getMainLooper())
    private val manager = context.getSystemService(BluetoothManager::class.java)
    private var gatt: BluetoothGatt? = null
    private var scannerCallback: ScanCallback? = null
    private var userDisconnect = false
    private var attempts = 0
    private var targetAddress: String? = null

    // Commands to EA02: one GATT write at a time, each waits for onCharacteristicWrite.
    private var command: BluetoothGattCharacteristic? = null
    private val writes = ArrayDeque<ByteArray>()
    private var writing = false
    private var ready = false
    private var writeToken = 0

    // Discovery round state. `session` invalidates callbacks and timeouts of older rounds.
    private var session = 0
    private var linked = false
    private var scanned = false
    private var current: Candidate? = null
    private val queue = ArrayDeque<Candidate>()
    private val queued = mutableSetOf<String>()
    private val report = mutableListOf<String>()
    private val seen = linkedMapOf<String, Seen>()
    private var headsets = listOf<BluetoothDevice>()

    fun connect(preferredAddress: String?, resetAttempts: Boolean = true) {
        if (resetAttempts) attempts = 0
        userDisconnect = false
        session += 1
        main.removeCallbacksAndMessages(null)
        stopScan()
        closeGatt()
        targetAddress = preferredAddress
        val adapter = manager?.adapter
        if (adapter == null || !adapter.isEnabled) {
            listener.onConnection("error", "Bluetooth недоступен.", null)
            return
        }
        if (!hasBlePermission()) {
            listener.onConnection("error", "Нет необходимого разрешения.", null)
            return
        }
        linked = false
        scanned = false
        current = null
        queue.clear()
        queued.clear()
        report.clear()
        seen.clear()
        headsets = emptyList()
        progress("Ищу очки…")
        loadHeadsets(adapter)
        if (!preferredAddress.isNullOrBlank() && BluetoothAdapter.checkBluetoothAddress(preferredAddress)) {
            enqueue(adapter.getRemoteDevice(preferredAddress), "сохранённые")
        }
        linkedOverLe().forEach { enqueue(it, "уже на связи по BLE") }
        tryNext()
    }

    fun disconnect() {
        userDisconnect = true
        session += 1
        main.removeCallbacksAndMessages(null)
        stopScan()
        closeGatt()
        linked = false
        attempts = 0
        listener.onConnection("disconnected", null, null)
    }

    fun release() {
        userDisconnect = true
        session += 1
        main.removeCallbacksAndMessages(null)
        stopScan()
        closeGatt()
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

    // ---- candidate sources

    /** Connected A2DP / hands-free devices: the glasses' classic side when they show "Active". */
    private fun loadHeadsets(adapter: BluetoothAdapter) {
        val token = session
        val found = linkedMapOf<String, BluetoothDevice>()
        for (profile in intArrayOf(BluetoothProfile.A2DP, BluetoothProfile.HEADSET)) {
            adapter.getProfileProxy(
                context,
                object : BluetoothProfile.ServiceListener {
                    override fun onServiceConnected(type: Int, proxy: BluetoothProfile) {
                        val devices = runCatching { proxy.connectedDevices }.getOrDefault(emptyList())
                        adapter.closeProfileProxy(type, proxy)
                        main.post {
                            if (token != session) return@post
                            devices.forEach { found[it.address] = it }
                            headsets = found.values.toList()
                            log("headsets: ${headsets.joinToString { "${nameOf(it)} ${it.address}" }}")
                        }
                    }

                    override fun onServiceDisconnected(type: Int) = Unit
                },
                profile,
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun linkedOverLe(): List<BluetoothDevice> {
        return runCatching { manager?.getConnectedDevices(BluetoothProfile.GATT).orEmpty() }
            .getOrDefault(emptyList())
    }

    @SuppressLint("MissingPermission")
    private fun bonded(): List<BluetoothDevice> {
        return runCatching { manager?.adapter?.bondedDevices?.toList().orEmpty() }.getOrDefault(emptyList())
    }

    @SuppressLint("MissingPermission")
    private fun startScan() {
        scanned = true
        val scanner = manager?.adapter?.bluetoothLeScanner
        if (scanner == null) {
            report += "поиск в эфире недоступен"
            afterScan()
            return
        }
        progress("Слушаю эфир…")
        val token = session
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                main.post { if (token == session) onSeen(result) }
            }

            override fun onScanFailed(errorCode: Int) {
                main.post {
                    if (token != session) return@post
                    log("scan failed $errorCode")
                    report += "поиск в эфире не запустился (код $errorCode)"
                    afterScan()
                }
            }
        }
        scannerCallback = callback
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        scanner.startScan(null, settings, callback)
        main.postDelayed({
            if (token == session && scannerCallback === callback) afterScan()
        }, SCAN_WINDOW_MS)
    }

    @SuppressLint("MissingPermission")
    private fun onSeen(result: ScanResult) {
        if (scannerCallback == null) return
        val device = result.device
        val record = result.scanRecord
        val name = record?.deviceName ?: nameOf(device).takeIf { it != device.address } ?: ""
        if (!seen.containsKey(device.address)) {
            log("seen ${device.address} ${result.rssi}dBm \"$name\" ${record?.serviceUuids.orEmpty()}")
        }
        seen[device.address] = Seen(device, name, result.rssi)
        if (record?.serviceUuids?.any { it.uuid == SERVICE_UUID } == true) {
            enqueue(device, "рекламирует FA00", front = true)
            afterScan()
        }
    }

    private fun afterScan() {
        stopScan()
        val nearby = seen.values.sortedByDescending { it.rssi }
        for (headset in headsets) {
            nearby.filter { twinOf(it, headset) }.forEach { enqueue(it.device, "BLE очков «${nameOf(headset)}»") }
        }
        headsets.forEach { enqueue(it, "наушники") }
        nearby.filter { GLASSES_NAME.containsMatchIn(it.name) }.forEach { enqueue(it.device, "в эфире") }
        bonded().filter { GLASSES_NAME.containsMatchIn(nameOf(it)) }.forEach { enqueue(it, "сопряжённые") }
        tryNext()
    }

    private fun twinOf(candidate: Seen, headset: BluetoothDevice): Boolean {
        val a = candidate.device.address
        val b = headset.address
        if (a == b || a.take(11) == b.take(11)) return true // same chip: address differs in the last byte
        return related(candidate.name, nameOf(headset))
    }

    private fun related(a: String, b: String): Boolean {
        val x = a.lowercase().filter { it.isLetterOrDigit() }
        val y = b.lowercase().filter { it.isLetterOrDigit() }
        if (x.length < 3 || y.length < 3) return false
        return x.contains(y) || y.contains(x) || (x.length >= 5 && y.length >= 5 && x.take(5) == y.take(5))
    }

    private fun enqueue(device: BluetoothDevice, why: String, front: Boolean = false) {
        if (!queued.add(device.address)) return
        val candidate = Candidate(device, "«${nameOf(device)}» ($why)")
        if (front) queue.addFirst(candidate) else queue.addLast(candidate)
    }

    // ---- trying candidates one by one

    @SuppressLint("MissingPermission")
    private fun tryNext() {
        if (userDisconnect) return
        closeGatt()
        current = null
        val next = if (report.size < MAX_CANDIDATES) queue.removeFirstOrNull() else null
        if (next == null) {
            if (!scanned && report.size < MAX_CANDIDATES) startScan() else roundFailed()
            return
        }
        current = next
        progress("Пробую ${next.label}…")
        log("connect ${next.device.address} ${next.label}")
        val token = session
        val attempt = next.device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        gatt = attempt
        main.postDelayed({
            if (token == session && gatt === attempt && !linked) fail("не отвечает")
        }, CONNECT_TIMEOUT_MS)
    }

    private fun fail(reason: String) {
        val label = current?.label ?: return
        log("fail $label: $reason")
        report += "$label: $reason"
        tryNext()
    }

    private fun roundFailed() {
        closeGatt()
        val summary = buildString {
            append(if (report.isEmpty()) "Подходящих устройств не нашлось." else "Проверено: ${report.joinToString("; ")}.")
            append(" В эфире устройств: ${seen.size}.")
            if (headsets.isNotEmpty()) append(" Наушники: ${headsets.joinToString { "«${nameOf(it)}»" }}.")
        }
        log("round failed: $summary")
        scheduleReconnect(summary)
    }

    private fun scheduleReconnect(detail: String?) {
        if (userDisconnect) return
        if (attempts >= MAX_ROUNDS - 1) {
            listener.onConnection("error", "Не удалось подключиться к очкам.", null, detail)
            return
        }
        attempts += 1
        listener.onConnection("reconnecting", null, null, detail)
        val token = session
        main.postDelayed({
            if (token == session && !userDisconnect) connect(targetAddress, resetAttempts = false)
        }, RETRY_DELAY_MS)
    }

    private fun progress(detail: String) {
        listener.onConnection(if (attempts == 0) "connecting" else "reconnecting", null, null, detail)
    }

    // ---- GATT

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            main.post { onState(gatt, status, newState) }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            main.post { onServices(gatt, status) }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            main.post { onNotifyEnabled(gatt, descriptor, status) }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            main.post { onMtu(gatt, mtu, status) }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            main.post { onWritten(gatt, status) }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            if (characteristic.uuid == NOTIFY_UUID) {
                val copy = value.copyOf()
                main.post { if (gatt === this@BleManager.gatt) listener.onPacket(copy) }
            }
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
    private fun onState(g: BluetoothGatt, status: Int, newState: Int) {
        if (userDisconnect || g !== gatt) return
        if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
            log("gatt connected ${g.device.address}")
            if (!linked) progress("Связь есть, читаю сервисы ${current?.label ?: ""}…")
            if (!g.discoverServices()) fail("не удалось запросить сервисы")
            return
        }
        if (linked) {
            // An established link dropped: reconnect to the same glasses.
            log("link lost ${g.device.address} status=$status")
            linked = false
            targetAddress = g.device.address
            closeGatt()
            scheduleReconnect("Связь с очками потеряна, подключаюсь снова.")
        } else {
            fail("связь не установилась (код $status)")
        }
    }

    @SuppressLint("MissingPermission")
    private fun onServices(g: BluetoothGatt, status: Int) {
        if (userDisconnect || g !== gatt) return
        if (status != BluetoothGatt.GATT_SUCCESS) {
            fail("сервисы не прочитались (код $status)")
            return
        }
        val notify = g.getService(SERVICE_UUID)?.getCharacteristic(NOTIFY_UUID)
        if (notify == null) {
            val services = g.services.joinToString(", ") { shortUuid(it.uuid) }
            log("no FA00 on ${g.device.address}: $services")
            fail("нет сервиса FA00 (есть: ${services.ifEmpty { "ничего" }})")
            return
        }
        command = g.getService(SERVICE_UUID)?.getCharacteristic(COMMAND_UUID)
        if (command == null) DiagLog.w(TAG, "no EA02: commands to the glasses are impossible")
        val descriptor = notify.getDescriptor(CCCD_UUID)
        if (descriptor == null) {
            fail("у EA01 нет дескриптора 2902")
            return
        }
        progress("Очки найдены, включаю уведомления…")
        g.setCharacteristicNotification(notify, true)
        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            g.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) ==
                BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            @Suppress("DEPRECATION")
            g.writeDescriptor(descriptor)
        }
        if (!started) fail("не удалось включить уведомления")
    }

    private fun onNotifyEnabled(g: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        if (userDisconnect || g !== gatt || descriptor.uuid != CCCD_UUID || linked) return
        if (status != BluetoothGatt.GATT_SUCCESS) {
            fail("очки не дали включить уведомления (код $status)")
            return
        }
        linked = true
        attempts = 0
        log("linked ${g.device.address} ${current?.label}")
        listener.onConnection("connected", null, g.device.address)
        DiagLog.i(TAG, "linked ${g.device.address}, notifications on")
        // Only after the descriptor write: Android runs one GATT operation at a time.
        // A big MTU lets a 50 KB photo come in 200-byte notifications instead of 20-byte ones.
        val token = session
        if (!g.requestMtu(MTU)) {
            markReady(g, "MTU request refused")
        } else {
            main.postDelayed({ if (token == session && gatt === g && !ready) markReady(g, "MTU timeout") }, 2_000)
        }
    }

    @SuppressLint("MissingPermission")
    private fun onMtu(g: BluetoothGatt, mtu: Int, status: Int) {
        if (g !== gatt || ready) return
        markReady(g, "MTU $mtu (status $status)")
    }

    @SuppressLint("MissingPermission")
    private fun markReady(g: BluetoothGatt, why: String) {
        ready = true
        DiagLog.i(TAG, "ready: $why")
        runCatching { g.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH) }
        listener.onReady()
        pump()
    }

    /** Frames a command and queues it for EA02. Main thread only. */
    fun send(cmd: Int, payload: ByteArray): Boolean {
        if (!linked || command == null) {
            DiagLog.w(TAG, "-> ${BkProtocol.name(cmd)} dropped: glasses not linked")
            return false
        }
        val data = BkProtocol.frame(cmd, payload)
        DiagLog.i(TAG, "-> ${BkProtocol.name(cmd)} ${data.hex()}")
        writes.addLast(data)
        pump()
        return true
    }

    @SuppressLint("MissingPermission")
    private fun pump() {
        if (writing || !ready) return
        val g = gatt ?: return
        val characteristic = command ?: return
        val data = writes.removeFirstOrNull() ?: return
        writing = true
        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            g.writeCharacteristic(characteristic, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) ==
                BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            @Suppress("DEPRECATION")
            characteristic.value = data
            @Suppress("DEPRECATION")
            g.writeCharacteristic(characteristic)
        }
        writeToken += 1
        val token = writeToken
        if (!started) {
            // Busy with another GATT operation: try again a bit later.
            writes.addFirst(data)
            writing = false
            main.postDelayed({ if (token == writeToken) pump() }, 60)
            return
        }
        main.postDelayed({
            if (token == writeToken && writing) {
                DiagLog.w(TAG, "write timeout ${data.copyOf(minOf(10, data.size)).hex()}")
                writing = false
                pump()
            }
        }, WRITE_TIMEOUT_MS)
    }

    private fun onWritten(g: BluetoothGatt, status: Int) {
        if (g !== gatt) return
        if (status != BluetoothGatt.GATT_SUCCESS) DiagLog.w(TAG, "write status $status")
        writing = false
        writeToken += 1
        pump()
    }

    @SuppressLint("MissingPermission")
    private fun stopScan() {
        val callback = scannerCallback ?: return
        scannerCallback = null
        runCatching { manager?.adapter?.bluetoothLeScanner?.stopScan(callback) }
    }

    @SuppressLint("MissingPermission")
    private fun closeGatt() {
        val current = gatt
        gatt = null
        ready = false
        writing = false
        writes.clear()
        command = null
        current?.close()
    }

    @SuppressLint("MissingPermission")
    private fun nameOf(device: BluetoothDevice): String {
        return runCatching { device.name }.getOrNull()?.takeIf { it.isNotBlank() }
            ?: seen[device.address]?.name?.takeIf { it.isNotBlank() }
            ?: device.address
    }

    private fun shortUuid(uuid: UUID): String {
        val text = uuid.toString()
        return if (text.endsWith(BASE_UUID_SUFFIX)) text.substring(4, 8).uppercase() else text
    }

    private fun log(message: String) = DiagLog.i(TAG, message)

    companion object {
        private const val TAG = "SeeSayBle"
        private const val SCAN_WINDOW_MS = 8_000L
        private const val CONNECT_TIMEOUT_MS = 10_000L
        private const val RETRY_DELAY_MS = 2_000L
        private const val MAX_CANDIDATES = 8
        private const val MAX_ROUNDS = 2
        private const val MTU = 247
        private const val WRITE_TIMEOUT_MS = 1_500L
        private const val BASE_UUID_SUFFIX = "-0000-1000-8000-00805f9b34fb"
        private val GLASSES_NAME = Regex("aimb|ai[\\s_-]?mb|s2|glass|очк|seesay", RegexOption.IGNORE_CASE)

        val SERVICE_UUID: UUID = UUID.fromString("0000fa00-0000-1000-8000-00805f9b34fb")
        val NOTIFY_UUID: UUID = UUID.fromString("0000ea01-0000-1000-8000-00805f9b34fb")
        val COMMAND_UUID: UUID = UUID.fromString("0000ea02-0000-1000-8000-00805f9b34fb")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        val BATTERY_SERVICE: UUID = UUID.fromString("0000180f-0000-1000-8000-00805f9b34fb")
        val BATTERY_LEVEL: UUID = UUID.fromString("00002a19-0000-1000-8000-00805f9b34fb")
    }
}
