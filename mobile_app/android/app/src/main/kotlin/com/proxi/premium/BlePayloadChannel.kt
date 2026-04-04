package com.proxi.premium

import android.annotation.SuppressLint
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

/**
 * BlePayloadChannel: Bridges BleGattService and Flutter via MethodChannel/EventChannel.
 * 
 * MethodChannel: "com.proxi.ble_payload"
 * - sendPayloadToClient(deviceId:String, payload:Uint8List)
 * - broadcastPayload(payload:Uint8List)
 * - getConnectedDevices() -> List<String> (device addresses)
 * - isRunning() -> Boolean
 * 
 * EventChannel: "com.proxi.ble_payload_stream"
 * - Emits: { "type": "payload|connected|disconnected", "deviceId": String, "payload": Uint8List? }
 */

@SuppressLint("MissingPermission")
class BlePayloadChannel(private val context: Context) {
    companion object {
        private const val TAG = "BlePayloadChannel"
        const val METHOD_CHANNEL = "com.proxi.ble_payload"
        const val EVENT_CHANNEL = "com.proxi.ble_payload_stream"
    }
    
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var gattService: BleGattService? = null
    private var eventSink: EventChannel.EventSink? = null
    
    /**
     * Initialize the channel with a FlutterEngine
     * Call this from MainActivity.configureFlutterEngine()
     */
    fun setupChannels(flutterEngine: FlutterEngine) {
        try {
            // Setup MethodChannel
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendPayloadToClient" -> {
                        val deviceId = call.argument<String>("deviceId")
                        val payload = call.argument<ByteArray>("payload")
                        if (deviceId != null && payload != null) {
                            sendPayloadToClient(deviceId, payload)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "deviceId and payload required", null)
                        }
                    }
                    "broadcastPayload" -> {
                        val payload = call.argument<ByteArray>("payload")
                        if (payload != null) {
                            broadcastPayload(payload)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "payload required", null)
                        }
                    }
                    "getConnectedDevices" -> {
                        val devices = getConnectedDevices()
                        result.success(devices)
                    }
                    "isRunning" -> {
                        result.success(isRunning())
                    }
                    "startGattServer" -> {
                        startGattServer()
                        result.success(true)
                    }
                    "stopGattServer" -> {
                        stopGattServer()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
            Log.d(TAG, "MethodChannel setup complete")
            
            // Setup EventChannel
            eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "EventChannel listener attached")
                }
                
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "EventChannel listener detached")
                }
            })
            Log.d(TAG, "EventChannel setup complete")
            
            // Start GATT server on initialization
            startGattServer()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up channels: ${e.message}", e)
        }
    }
    
    /**
     * Start GATT server and bind to service
     */
    private fun startGattServer() {
        try {
            if (gattService == null) {
                gattService = BleGattService(context)
            }
            gattService?.start()
            
            // Setup callbacks
            gattService?.setOnPayloadReceivedCallback { payload ->
                Log.d(TAG, "Payload received: ${payload.size} bytes")
                emitEvent(mapOf(
                    "type" to "payload",
                    "payload" to payload
                ))
            }
            
            gattService?.setOnClientConnectedCallback { device ->
                Log.d(TAG, "Client connected: ${device.address}")
                emitEvent(mapOf(
                    "type" to "connected",
                    "deviceId" to device.address
                ))
            }
            
            gattService?.setOnClientDisconnectedCallback { device ->
                Log.d(TAG, "Client disconnected: ${device.address}")
                emitEvent(mapOf(
                    "type" to "disconnected",
                    "deviceId" to device.address
                ))
            }
            
            Log.d(TAG, "GATT server started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting GATT server: ${e.message}", e)
        }
    }
    
    /**
     * Stop GATT server
     */
    private fun stopGattServer() {
        try {
            gattService?.stop()
            gattService = null
            Log.d(TAG, "GATT server stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping GATT server: ${e.message}", e)
        }
    }
    
    /**
     * Send payload to specific device
     */
    private fun sendPayloadToClient(deviceId: String, payload: ByteArray) {
        try {
            gattService?.let { service ->
                // Find device by address
                val device = service.getConnectedDevices().find { it.address == deviceId }
                if (device != null) {
                    service.sendPayloadToClient(device, payload)
                    Log.d(TAG, "Sent payload to device: $deviceId size=${payload.size}")
                } else {
                    Log.w(TAG, "Device not found or not connected: $deviceId")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending payload: ${e.message}", e)
        }
    }
    
    /**
     * Broadcast payload to all connected devices
     */
    private fun broadcastPayload(payload: ByteArray) {
        try {
            gattService?.broadcastPayload(payload)
            Log.d(TAG, "Broadcast payload: ${payload.size} bytes")
        } catch (e: Exception) {
            Log.e(TAG, "Error broadcasting payload: ${e.message}", e)
        }
    }
    
    /**
     * Get list of connected device addresses
     */
    private fun getConnectedDevices(): List<String> {
        return try {
            gattService?.getConnectedDevices()?.map { it.address } ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting connected devices: ${e.message}", e)
            emptyList()
        }
    }
    
    /**
     * Check if GATT server is running
     */
    private fun isRunning(): Boolean {
        return gattService?.isRunning() ?: false
    }
    
    /**
     * Emit event through EventChannel
     */
    private fun emitEvent(event: Map<String, Any?>) {
        try {
            eventSink?.success(event)
        } catch (e: Exception) {
            Log.e(TAG, "Error emitting event: ${e.message}", e)
        }
    }
}
