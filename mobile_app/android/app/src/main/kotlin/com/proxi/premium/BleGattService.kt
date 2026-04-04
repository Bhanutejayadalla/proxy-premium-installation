package com.proxi.premium

import android.annotation.SuppressLint
import android.bluetooth.*
import android.content.Context
import android.util.Log
import java.util.UUID

/**
 * BleGattService: Hosts a GATT server for dual-transport mesh messaging over BLE.
 * 
 * Characteristics:
 * - Mesh Payload Write: UUID_MESH_WRITE - client writes encrypted mesh packets here
 * - Mesh Payload Notify: UUID_MESH_NOTIFY - server notifies incoming relay/discovery packets
 * 
 * Packet format: [length_byte:1][packet_data:0-255]
 * Supports fragmentation for payloads >255 bytes via continuation marker in fragment header.
 * 
 * Flow:
 * 1. Central (mobile device) discovers Proxi peripheral
 * 2. Central connects and subscribes to Mesh Payload Notify (notifications enabled)
 * 3. Central writes encrypted mesh packet to Mesh Payload Write
 * 4. Server processes, relays, or forwards to local clients
 * 5. Server broadcasts response/relay via Mesh Payload Notify
 */

@SuppressLint("MissingPermission")
class BleGattService(private val context: Context) {
    companion object {
        private const val TAG = "BleGattService"
        
        // Mesh service UUID (custom, not reserved by Bluetooth SIG)
        private val UUID_MESH_SERVICE = UUID.fromString("12345678-1234-5678-1234-56789abcdef0")
        // Write characteristic: client -> server
        private val UUID_MESH_WRITE = UUID.fromString("12345678-1234-5678-1234-56789abcdef1")
        // Notify characteristic: server -> client
        private val UUID_MESH_NOTIFY = UUID.fromString("12345678-1234-5678-1234-56789abcdef2")
        
        // GATT descriptors for write/notify configuration
        private val UUID_CLIENT_CHAR_CONFIG = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        
        // Packet size limits
        private const val MAX_PACKET_SIZE = 256
        
        // Fragment continuation marker (high bit of first byte in multi-fragment packet)
        private const val FRAGMENT_CONTINUATION_MASK = 0x80
    }
    
    private lateinit var bluetoothManager: BluetoothManager
    private lateinit var bluetoothAdapter: BluetoothAdapter
    private var gattServer: BluetoothGattServer? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    private var notifyCharacteristic: BluetoothGattCharacteristic? = null
    
    // Callback delegates (set by BlePayloadChannel)
    private var onPayloadReceivedCallback: ((ByteArray) -> Unit)? = null
    private var onClientConnectedCallback: ((BluetoothDevice) -> Unit)? = null
    private var onClientDisconnectedCallback: ((BluetoothDevice) -> Unit)? = null
    
    // Fragment reassembly buffers: device -> (fragmentBuffer)
    private val fragmentBuffers = mutableMapOf<String, ByteArray>()
    
    init {
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        Log.d(TAG, "BleGattService initialized")
    }

    fun start() {
        if (gattServer != null) return
        startGattServer()
    }
    
    /**
     * Start the GATT server with mesh service and characteristics
     */
    private fun startGattServer() {
        try {
            // Create GATT server callback
            val gattServerCallback = object : BluetoothGattServerCallback() {
                override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
                    Log.d(TAG, "Connection state change: device=${device?.address}, status=$status, newState=$newState")
                    device?.let {
                        when (newState) {
                            BluetoothProfile.STATE_CONNECTED -> {
                                Log.d(TAG, "Client connected: ${device.address}")
                                onClientConnectedCallback?.invoke(device)
                            }
                            BluetoothProfile.STATE_DISCONNECTED -> {
                                Log.d(TAG, "Client disconnected: ${device.address}")
                                fragmentBuffers.remove(device.address)
                                onClientDisconnectedCallback?.invoke(device)
                            }
                        }
                    }
                }
                
                override fun onCharacteristicReadRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    offset: Int,
                    characteristic: BluetoothGattCharacteristic?
                ) {
                    Log.d(TAG, "Read request: ${characteristic?.uuid} offset=$offset")
                    device?.let {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_SUCCESS,
                            offset,
                            characteristic?.value
                        )
                    }
                }
                
                override fun onCharacteristicWriteRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    characteristic: BluetoothGattCharacteristic?,
                    preparedWrite: Boolean,
                    responseNeeded: Boolean,
                    offset: Int,
                    value: ByteArray?
                ) {
                    Log.d(TAG, "Write request: uuid=${characteristic?.uuid}, size=${value?.size ?: 0}, device=${device?.address}")
                    if (characteristic?.uuid == UUID_MESH_WRITE && value != null && device != null) {
                        handleMeshPayloadWrite(device, requestId, value)
                        if (responseNeeded) {
                            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                        }
                    } else if (responseNeeded) {
                        device?.let {
                            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
                        }
                    }
                }
                
                override fun onDescriptorWriteRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    descriptor: BluetoothGattDescriptor?,
                    preparedWrite: Boolean,
                    responseNeeded: Boolean,
                    offset: Int,
                    value: ByteArray?
                ) {
                    Log.d(TAG, "Descriptor write: uuid=${descriptor?.uuid}, value size=${value?.size ?: 0}")
                    if (descriptor?.uuid == UUID_CLIENT_CHAR_CONFIG) {
                        device?.let {
                            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                        }
                    } else if (responseNeeded) {
                        device?.let {
                            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
                        }
                    }
                }
                
                override fun onDescriptorReadRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    offset: Int,
                    descriptor: BluetoothGattDescriptor?
                ) {
                    Log.d(TAG, "Descriptor read: uuid=${descriptor?.uuid}")
                    if (descriptor?.uuid == UUID_CLIENT_CHAR_CONFIG) {
                        device?.let {
                            // Return CCCD value: 0x0001 for notifications enabled
                            val value = byteArrayOf(0x01, 0x00)
                            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                        }
                    } else if (device != null) {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
                    }
                }
            }
            
            gattServer = bluetoothManager.openGattServer(context, gattServerCallback)
            
            // Create GATT service and characteristics
            val meshService = BluetoothGattService(UUID_MESH_SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            
            // Write characteristic: client -> server (no response, encrypted payload)
            writeCharacteristic = BluetoothGattCharacteristic(
                UUID_MESH_WRITE,
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_WRITE,
                BluetoothGattCharacteristic.PERMISSION_WRITE
            )
            meshService.addCharacteristic(writeCharacteristic)
            
            // Notify characteristic: server -> client (notifications)
            notifyCharacteristic = BluetoothGattCharacteristic(
                UUID_MESH_NOTIFY,
                BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_READ,
                BluetoothGattCharacteristic.PERMISSION_READ
            )
            notifyCharacteristic?.value = byteArrayOf()  // Initialize with empty value
            
            // Add CCCD descriptor for notify characteristic
            val cccd = BluetoothGattDescriptor(
                UUID_CLIENT_CHAR_CONFIG,
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
            )
            notifyCharacteristic?.addDescriptor(cccd)
            meshService.addCharacteristic(notifyCharacteristic)
            
            gattServer?.addService(meshService)
            Log.d(TAG, "GATT server started successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting GATT server: ${e.message}", e)
        }
    }
    
    /**
     * Handle incoming mesh payload write from client
     * Reassemble fragmented packets and invoke callback
     */
    private fun handleMeshPayloadWrite(device: BluetoothDevice, requestId: Int, value: ByteArray) {
        if (value.isEmpty()) {
            Log.w(TAG, "Received empty payload from ${device.address}")
            return
        }
        
        val deviceAddress = device.address
        val firstByte = value[0].toInt() and 0xFF
        val isFragmentContinuation = (firstByte and FRAGMENT_CONTINUATION_MASK) != 0
        val payloadLength = if (isFragmentContinuation) {
            firstByte and 0x7F
        } else {
            firstByte
        }
        
        val payload = if (value.size > 1) value.sliceArray(1 until minOf(value.size, payloadLength + 1)) else byteArrayOf()
        
        // Check if this is a continuation fragment
        val buffer = fragmentBuffers[deviceAddress]
        val completePayload = if (isFragmentContinuation && buffer != null) {
            // Append to existing buffer
            buffer + payload
        } else if (isFragmentContinuation) {
            // Orphaned continuation fragment, start new buffer
            Log.w(TAG, "Orphaned continuation fragment from $deviceAddress")
            payload
        } else {
            // Single packet or start of new sequence
            payload
        }
        
        // Check if more fragments expected (last byte indicates continuation)
        val lastByte = value.last().toInt() and 0xFF
        if ((lastByte and FRAGMENT_CONTINUATION_MASK) != 0) {
            // More fragments expected, store buffer
            fragmentBuffers[deviceAddress] = completePayload
            Log.d(TAG, "Fragment reassembly: buffer size=${completePayload.size}, expecting more")
        } else {
            // Final fragment or single packet
            fragmentBuffers.remove(deviceAddress)
            Log.d(TAG, "Mesh payload received: size=${completePayload.size}, device=$deviceAddress")
            onPayloadReceivedCallback?.invoke(completePayload)
        }
    }
    
    /**
     * Send mesh payload to connected client via notify
     * Automatically fragments if payload > MAX_PACKET_SIZE
     */
    fun sendPayloadToClient(device: BluetoothDevice, payload: ByteArray) {
        if (payload.isEmpty()) {
            Log.w(TAG, "Attempted to send empty payload")
            return
        }
        
        notifyCharacteristic?.let { characteristic ->
            // Fragment if needed
            if (payload.size <= MAX_PACKET_SIZE) {
                // Single packet
                val packet = byteArrayOf(payload.size.toByte()) + payload
                characteristic.value = packet
                gattServer?.notifyCharacteristicChanged(device, characteristic, false)
                Log.d(TAG, "Sent mesh payload to ${device.address}: size=${payload.size}")
            } else {
                // Multi-fragment transmission
                var offset = 0
                var fragmentIndex = 0
                while (offset < payload.size) {
                    val chunkSize = minOf(MAX_PACKET_SIZE, payload.size - offset)
                    val fragment = payload.sliceArray(offset until offset + chunkSize)
                    
                    // First byte: length with continuation bit
                    val headerByte = if (offset + chunkSize < payload.size) {
                        // More fragments coming
                        (chunkSize or FRAGMENT_CONTINUATION_MASK).toByte()
                    } else {
                        chunkSize.toByte()
                    }
                    
                    val packet = byteArrayOf(headerByte) + fragment
                    characteristic.value = packet
                    gattServer?.notifyCharacteristicChanged(device, characteristic, false)
                    Log.d(TAG, "Sent fragment $fragmentIndex to ${device.address}: size=$chunkSize, continuation=${(headerByte.toInt() and FRAGMENT_CONTINUATION_MASK) != 0}")
                    
                    offset += chunkSize
                    fragmentIndex++
                    
                    // Small delay between fragments to ensure delivery
                    Thread.sleep(10)
                }
            }
        }
    }
    
    /**
     * Broadcast payload to all connected clients
     */
    fun broadcastPayload(payload: ByteArray) {
        gattServer?.connectedDevices?.forEach { device ->
            sendPayloadToClient(device, payload)
        }
    }
    
    /**
     * Register callback for incoming mesh payloads
     */
    fun setOnPayloadReceivedCallback(callback: (ByteArray) -> Unit) {
        onPayloadReceivedCallback = callback
    }
    
    /**
     * Register callback for client connection events
     */
    fun setOnClientConnectedCallback(callback: (BluetoothDevice) -> Unit) {
        onClientConnectedCallback = callback
    }
    
    /**
     * Register callback for client disconnection events
     */
    fun setOnClientDisconnectedCallback(callback: (BluetoothDevice) -> Unit) {
        onClientDisconnectedCallback = callback
    }
    
    /**
     * Get list of connected BLE devices
     */
    fun getConnectedDevices(): List<BluetoothDevice> {
        return gattServer?.connectedDevices ?: emptyList()
    }
    
    /**
     * Check if GATT server is running
     */
    fun isRunning(): Boolean {
        return gattServer != null
    }
    
    fun stop() {
        gattServer?.close()
        gattServer = null
        fragmentBuffers.clear()
        Log.d(TAG, "BleGattService stopped")
    }
}
