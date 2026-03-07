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
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "BLE-Advertiser"
        private const val PROXI_COMPANY_ID = 0xFF01  // Must match BleService.proxiCompanyId in Dart
    }

    private val CHANNEL = "com.proxi.ble_advertiser"

    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var isAdvertising = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Registering MethodChannel: $CHANNEL")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "MethodChannel call: ${call.method}")
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

    private fun startAdvertising(uid: String, result: MethodChannel.Result) {
        val uidPreview = uid.take(8)
        Log.d(TAG, "startAdvertising: uid=$uidPreview…, currentlyAdvertising=$isAdvertising")

        if (isAdvertising) {
            Log.d(TAG, "Already advertising — returning success")
            result.success(true)
            return
        }

        // Check BLUETOOTH_ADVERTISE permission (Android 12+)
        if (!hasAdvertisePermission()) {
            Log.e(TAG, "BLUETOOTH_ADVERTISE permission not granted — cannot advertise")
            result.error("PERMISSION_DENIED", "BLUETOOTH_ADVERTISE permission not granted. Grant it in app settings.", null)
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
            Log.e(TAG, "bluetoothLeAdvertiser is null — peripheral mode not supported on this device")
            result.error("NO_ADVERTISER", "BLE peripheral mode not supported on this device", null)
            return
        }

        // Encode UID into manufacturer data:
        //   BLE advert limit = 31 bytes total.
        //   Flags(3) + Mfg type(1) + length(1) + company_id(2) + payload ≤ 31 → max 24 bytes payload.
        //   We use 20 bytes (truncated UID) to stay safely under limit.
        //   Scanner looks for company ID 0xFF01 (= 65281) and decodes the bytes as UTF-8 UID.
        val uidBytes = uid.toByteArray(Charsets.UTF_8).take(20).toByteArray()
        Log.d(TAG, "Advertising with companyId=0x${PROXI_COMPANY_ID.toString(16).uppercase()} (${PROXI_COMPANY_ID}), uidBytes.size=${uidBytes.size}")

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)  // Most responsive
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)      // Maximum range
            .setConnectable(false)
            .setTimeout(0) // Advertise indefinitely (0 = no timeout)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)         // Save packet space
            .setIncludeTxPowerLevel(false)       // Save packet space
            // No service UUID: takes 18 bytes and pushes packet OVER the 31-byte BLE limit.
            // Proxi identification uses manufacturer data company ID 0xFF01 instead.
            .addManufacturerData(PROXI_COMPANY_ID, uidBytes)
            .build()

        Log.d(TAG, "AdvertiseSettings: mode=LOW_LATENCY, txPower=HIGH, connectable=false, timeout=0")
        Log.d(TAG, "AdvertiseData: includeDeviceName=false, mfData companyId=$PROXI_COMPANY_ID bytes=${uidBytes.size}")

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                isAdvertising = true
                Log.i(TAG, ">>> BLE Advertising STARTED SUCCESSFULLY for uid=$uidPreview")
                result.success(true)
            }

            override fun onStartFailure(errorCode: Int) {
                isAdvertising = false
                val errorMsg = when (errorCode) {
                    ADVERTISE_FAILED_ALREADY_STARTED -> "ADVERTISE_FAILED_ALREADY_STARTED (1)"
                    ADVERTISE_FAILED_DATA_TOO_LARGE -> "ADVERTISE_FAILED_DATA_TOO_LARGE (2)"
                    ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "ADVERTISE_FAILED_FEATURE_UNSUPPORTED (3)"
                    ADVERTISE_FAILED_INTERNAL_ERROR -> "ADVERTISE_FAILED_INTERNAL_ERROR (4)"
                    ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS (5)"
                    else -> "UNKNOWN_ERROR_$errorCode"
                }
                Log.e(TAG, ">>> BLE Advertising FAILED: $errorMsg")
                // Handle already-started as success (another call may have started it)
                if (errorCode == ADVERTISE_FAILED_ALREADY_STARTED) {
                    isAdvertising = true
                    result.success(true)
                } else {
                    result.error("ADV_FAILED", errorMsg, "errorCode=$errorCode")
                }
            }
        }

        try {
            advertiser?.startAdvertising(settings, data, advertiseCallback)
            Log.d(TAG, "startAdvertising() called on BluetoothLeAdvertiser — waiting for callback...")
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException in startAdvertising: ${e.message}")
            result.error("PERMISSION", "Bluetooth advertise permission denied at runtime: ${e.message}", null)
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
                Log.w(TAG, "SecurityException stopping advertising (permission revoked?): ${e.message}")
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping advertising: ${e.message}")
            }
        }
        isAdvertising = false
        advertiseCallback = null
        result.success(true)
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy — stopping advertising")
        if (advertiser != null && advertiseCallback != null) {
            try {
                advertiser?.stopAdvertising(advertiseCallback)
            } catch (_: Exception) {}
        }
        isAdvertising = false
        super.onDestroy()
    }
}
