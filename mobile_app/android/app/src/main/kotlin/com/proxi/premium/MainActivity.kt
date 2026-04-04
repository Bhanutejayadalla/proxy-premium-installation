package com.proxi.premium

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "BLE-Advertiser"
        /** Must match BleService.proxiCompanyId in Dart. */
        private const val PROXI_COMPANY_ID = 0xFF01
        /** Must match BleService.proxiServiceUuid in Dart (scan-response service data). */
        private val PROXI_SERVICE_UUID =
            ParcelUuid.fromString("0000FF01-0000-1000-8000-00805F9B34FB")
    }

    private val CHANNEL = "com.proxi.ble_advertiser"

    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var isAdvertising = false

    // Wi-Fi Direct plugin for mesh networking
    private var wifiDirectPlugin: WifiDirectPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Registering MethodChannel: $CHANNEL")

        // ── BLE Advertiser channel (existing) ─────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "MethodChannel call: ${call.method}")
                when (call.method) {
                    "startAdvertising" -> {
                        val uid      = call.argument<String>("uid")      ?: ""
                        val username = call.argument<String>("username") ?: ""
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        startAdvertising(uid, username, deviceId, result)
                    }
                    "stopAdvertising" -> {
                        stopAdvertising(result)
                    }
                    "isAdvertising" -> {
                        result.success(isAdvertising)
                    }
                    "isAdvertisingSupported" -> {
                        result.success(isAdvertisingSupported())
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Wi-Fi Direct channel (mesh networking) ────────────────────────
        val wfdMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.proxi.wifi_direct"
        )
        val wfdEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.proxi.wifi_direct/events"
        )
        wifiDirectPlugin = WifiDirectPlugin(this, wfdMethodChannel)
        wfdMethodChannel.setMethodCallHandler(wifiDirectPlugin)
        wfdEventChannel.setStreamHandler(wifiDirectPlugin)

        // ── BLE Payload channel (GATT server for mesh dual-transport) ─────
        val blePayloadChannel = BlePayloadChannel(this)
        blePayloadChannel.setupChannels(flutterEngine)
        Log.d(TAG, "BLE Payload channel initialized")
    }

    /** Returns true if this device supports BLE peripheral/advertising mode. */
    private fun isAdvertisingSupported(): Boolean {
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter ?: return false
        val supported = adapter.bluetoothLeAdvertiser != null
        Log.d(TAG, "isAdvertisingSupported: $supported")
        return supported
    }

    /** Check that BLUETOOTH_ADVERTISE runtime permission is granted (required on Android 12+). */
    private fun hasAdvertisePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_ADVERTISE
            ) == PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "BLUETOOTH_ADVERTISE permission granted: $granted")
            granted
        } else {
            true // Not required on Android 11 and below
        }
    }

    private fun startAdvertising(
        uid: String,
        username: String,
        deviceId: String,
        result: MethodChannel.Result
    ) {
        val uidPreview = uid.take(8)
        Log.d(TAG, "startAdvertising: uid=${uidPreview}..., username=$username, " +
                "currentlyAdvertising=$isAdvertising")

        if (isAdvertising) {
            Log.d(TAG, "Already advertising â€” returning success")
            result.success(true)
            return
        }

        // Check BLUETOOTH_ADVERTISE permission (Android 12+)
        if (!hasAdvertisePermission()) {
            Log.e(TAG, "BLUETOOTH_ADVERTISE permission not granted â€” cannot advertise")
            result.error(
                "PERMISSION_DENIED",
                "BLUETOOTH_ADVERTISE permission not granted. Grant it in app settings.",
                null
            )
            return
        }

        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter
        if (adapter == null || !adapter.isEnabled) {
            Log.e(TAG, "Bluetooth adapter is OFF or unavailable")
            result.error("BT_OFF", "Bluetooth adapter is off or unavailable", null)
            return
        }

        advertiser = adapter.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.e(TAG, "bluetoothLeAdvertiser is null â€” peripheral mode not supported")
            result.error(
                "NO_ADVERTISER",
                "BLE peripheral mode not supported on this device",
                null
            )
            return
        }

        // â”€â”€ Advertisement data (31-byte window) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        // Flags(3) + Mfg type(1) + length(1) + companyId(2) + payload â‰¤ 31 bytes
        // â†’ max 24 bytes payload; we use 20 bytes (truncated UID) to stay safe.
        val uidBytes = uid.toByteArray(Charsets.UTF_8).take(20).toByteArray()
        Log.d(TAG, "Adv data: companyId=0x${PROXI_COMPANY_ID.toString(16).uppercase()}, " +
                "uidBytes.size=${uidBytes.size}")

        val advData = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addManufacturerData(PROXI_COMPANY_ID, uidBytes)
            .build()

        // -- Scan response (second 31-byte window) ----------------------------
        // 128-bit UUID service data overhead: Length(1)+Type(1)+UUID(16) = 18 bytes
        // -> max payload = 31 - 18 = 13 bytes
        // Format: username\x00deviceId  (null-delimited)
        // Budget: username(8) + null(1) + deviceId(4) = 13 bytes exactly
        val usernamePrefix = username.take(8)        // max 8 chars for username
        val deviceIdPrefix = deviceId.take(4)        // max 4 chars for device id
        val scanRespPayload = "$usernamePrefix\u0000$deviceIdPrefix"
            .toByteArray(Charsets.UTF_8)
        Log.d(TAG, "Scan response: username='$usernamePrefix', deviceId='$deviceIdPrefix', " +
                "payloadBytes=${scanRespPayload.size}")

        val scanRespData = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceData(PROXI_SERVICE_UUID, scanRespPayload)
            .build()

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .setTimeout(0) // Advertise indefinitely
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                isAdvertising = true
                Log.i(TAG, ">>> BLE Advertising STARTED for uid=$uidPreview, username=$usernamePrefix")
                runOnUiThread { result.success(true) }
            }

            override fun onStartFailure(errorCode: Int) {
                isAdvertising = false
                val errorMsg = when (errorCode) {
                    ADVERTISE_FAILED_ALREADY_STARTED     -> "ADVERTISE_FAILED_ALREADY_STARTED (1)"
                    ADVERTISE_FAILED_DATA_TOO_LARGE      -> "ADVERTISE_FAILED_DATA_TOO_LARGE (2)"
                    ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "ADVERTISE_FAILED_FEATURE_UNSUPPORTED (3)"
                    ADVERTISE_FAILED_INTERNAL_ERROR      -> "ADVERTISE_FAILED_INTERNAL_ERROR (4)"
                    ADVERTISE_FAILED_TOO_MANY_ADVERTISERS-> "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS (5)"
                    else -> "UNKNOWN_ERROR_$errorCode"
                }
                Log.e(TAG, ">>> BLE Advertising FAILED: $errorMsg")
                if (errorCode == ADVERTISE_FAILED_ALREADY_STARTED) {
                    isAdvertising = true
                    runOnUiThread { result.success(true) }
                } else {
                    runOnUiThread { result.error("ADV_FAILED", errorMsg, "errorCode=$errorCode") }
                }
            }
        }

        try {
            advertiser?.startAdvertising(settings, advData, scanRespData, advertiseCallback)
            Log.d(TAG, "startAdvertising() called â€” waiting for callback...")
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException in startAdvertising: ${e.message}")
            result.error("PERMISSION", "Advertise permission denied: ${e.message}", null)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error in startAdvertising: ${e.message}")
            result.error("ADV_ERROR", "Unexpected error: ${e.message}", null)
        }
    }

    private fun stopAdvertising(result: MethodChannel.Result) {
        Log.d(TAG, "stopAdvertising called, isAdvertising=$isAdvertising")
        if (advertiser != null && advertiseCallback != null) {
            try {
                advertiser?.stopAdvertising(advertiseCallback)
                Log.i(TAG, "BLE Advertising STOPPED")
            } catch (e: SecurityException) {
                Log.w(TAG, "SecurityException stopping advertising: ${e.message}")
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping advertising: ${e.message}")
            }
        }
        isAdvertising = false
        advertiseCallback = null
        result.success(true)
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy — stopping advertising + WiFi Direct")
        if (advertiser != null && advertiseCallback != null) {
            try { advertiser?.stopAdvertising(advertiseCallback) } catch (_: Exception) {}
        }
        isAdvertising = false
        wifiDirectPlugin?.dispose()
        wifiDirectPlugin = null
        super.onDestroy()
    }
}
