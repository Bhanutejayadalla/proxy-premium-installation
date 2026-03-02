package com.example.dual_mode_app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.proxi.ble_advertiser"

    // Proxi custom BLE service UUID — all Proxi apps use this for discovery
    private val PROXI_SERVICE_UUID: UUID =
        UUID.fromString("0000B1E0-PRXI-4A5B-8D2E-0123456789AB".replace("PRXI", "9999"))

    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var isAdvertising = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAdvertising" -> {
                        val uid = call.argument<String>("uid") ?: ""
                        startAdvertising(uid, result)
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
    }

    private fun isAdvertisingSupported(): Boolean {
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter ?: return false
        return adapter.bluetoothLeAdvertiser != null
    }

    private fun startAdvertising(uid: String, result: MethodChannel.Result) {
        if (isAdvertising) {
            result.success(true)
            return
        }

        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BT_OFF", "Bluetooth adapter is off or unavailable", null)
            return
        }

        advertiser = adapter.bluetoothLeAdvertiser
        if (advertiser == null) {
            result.error("NO_ADVERTISER", "BLE advertising not supported on this device", null)
            return
        }

        // Encode UID into manufacturer data (Company ID 0xFF01 + UID bytes)
        // Max 24 bytes for UID (fits Firebase UIDs which are 28 chars — we truncate safely)
        val uidBytes = uid.toByteArray(Charsets.UTF_8).take(24).toByteArray()
        val companyId = 0xFF01  // Custom/test company ID
        val manufacturerData = uidBytes

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .setTimeout(0) // Advertise indefinitely
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(ParcelUuid(PROXI_SERVICE_UUID))
            .addManufacturerData(companyId, manufacturerData)
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                isAdvertising = true
                result.success(true)
            }

            override fun onStartFailure(errorCode: Int) {
                isAdvertising = false
                val errorMsg = when (errorCode) {
                    ADVERTISE_FAILED_ALREADY_STARTED -> "Already advertising"
                    ADVERTISE_FAILED_DATA_TOO_LARGE -> "Data too large"
                    ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature unsupported"
                    ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                    ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                    else -> "Unknown error: $errorCode"
                }
                result.error("ADV_FAILED", errorMsg, null)
            }
        }

        try {
            advertiser?.startAdvertising(settings, data, advertiseCallback)
        } catch (e: SecurityException) {
            result.error("PERMISSION", "Bluetooth advertise permission denied", e.message)
        }
    }

    private fun stopAdvertising(result: MethodChannel.Result) {
        if (advertiser != null && advertiseCallback != null) {
            try {
                advertiser?.stopAdvertising(advertiseCallback)
            } catch (_: SecurityException) {
                // Permission revoked — ignore
            }
        }
        isAdvertising = false
        advertiseCallback = null
        result.success(true)
    }

    override fun onDestroy() {
        // Clean up advertising when activity is destroyed
        if (advertiser != null && advertiseCallback != null) {
            try {
                advertiser?.stopAdvertising(advertiseCallback)
            } catch (_: SecurityException) {}
        }
        isAdvertising = false
        super.onDestroy()
    }
}
