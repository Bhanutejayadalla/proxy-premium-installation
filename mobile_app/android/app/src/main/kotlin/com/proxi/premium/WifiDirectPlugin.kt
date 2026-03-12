package com.proxi.premium

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.NetworkInfo
import android.net.wifi.p2p.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.*
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

/**
 * Native Android Wi-Fi Direct (P2P) plugin for mesh networking.
 *
 * Architecture:
 *   Flutter → MethodChannel → WifiDirectPlugin → WifiP2pManager
 *   WifiDirectPlugin → EventChannel → Flutter (events)
 *
 * Socket protocol: newline-delimited JSON messages over TCP port 8888.
 */
class WifiDirectPlugin(
    private val activity: android.app.Activity,
    private val methodChannel: MethodChannel
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "WiFiDirect"
        private const val SOCKET_PORT = 8888
        private const val SOCKET_TIMEOUT = 10000
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Wi-Fi P2P core ────────────────────────────────────────────────
    private var manager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null
    private var receiver: BroadcastReceiver? = null
    private var isWifiP2pEnabled = false
    private var isInitialized = false

    // ── Connection state ──────────────────────────────────────────────
    private var isGroupOwner = false
    private var groupOwnerAddress: String? = null
    private var isConnected = false

    // ── Socket state ──────────────────────────────────────────────────
    private var serverSocket: ServerSocket? = null
    private val clientSockets = mutableListOf<Socket>()
    // ConcurrentHashMap so server, client, reader, and send threads can all
    // access socketStreams without ConcurrentModificationException.
    private val socketStreams = ConcurrentHashMap<String, OutputStream>()
    private var serverThread: Thread? = null

    // ── Peers ─────────────────────────────────────────────────────────
    private val discoveredPeers = mutableListOf<WifiP2pDevice>()

    // ── Event sink (native → Flutter) ─────────────────────────────────
    private var eventSink: EventChannel.EventSink? = null

    // ═══════════════════════════════════════════════════════════════════
    //  MethodChannel.MethodCallHandler
    // ═══════════════════════════════════════════════════════════════════

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> result.success(initialize())
            "startDiscovery" -> startDiscovery(result)
            "stopDiscovery" -> stopDiscovery(result)
            "connectToPeer" -> {
                val address = call.argument<String>("address") ?: ""
                connectToPeer(address, result)
            }
            "disconnect" -> disconnect(result)
            "sendMessage" -> {
                val message = call.argument<String>("message") ?: ""
                val target = call.argument<String>("targetAddress")
                sendMessage(message, target, result)
            }
            "getPeers" -> result.success(getPeersJson())
            "getConnectionInfo" -> getConnectionInfo(result)
            "dispose" -> { dispose(); result.success(true) }
            else -> result.notImplemented()
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  EventChannel.StreamHandler
    // ═══════════════════════════════════════════════════════════════════

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "EventSink attached")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "EventSink detached")
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Initialize WifiP2pManager
    // ═══════════════════════════════════════════════════════════════════

    private fun initialize(): Boolean {
        if (isInitialized) return true

        manager = activity.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
        if (manager == null) {
            Log.e(TAG, "Wi-Fi P2P not supported on this device")
            return false
        }

        channel = manager?.initialize(activity, Looper.getMainLooper()) {
            Log.w(TAG, "Wi-Fi P2P channel disconnected")
            isConnected = false
            sendEvent("channelDisconnected", null)
        }

        if (channel == null) {
            Log.e(TAG, "Failed to initialize Wi-Fi P2P channel")
            return false
        }

        registerReceiver()
        isInitialized = true
        Log.d(TAG, "Wi-Fi Direct initialized successfully")
        return true
    }

    // ═══════════════════════════════════════════════════════════════════
    //  BroadcastReceiver for Wi-Fi P2P system events
    // ═══════════════════════════════════════════════════════════════════

    private fun registerReceiver() {
        receiver = object : BroadcastReceiver() {
            @SuppressLint("MissingPermission")
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {

                    // ── 1. P2P state (enabled / disabled) ─────────────────
                    WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                        val state = intent.getIntExtra(
                            WifiP2pManager.EXTRA_WIFI_STATE,
                            WifiP2pManager.WIFI_P2P_STATE_DISABLED
                        )
                        isWifiP2pEnabled = state == WifiP2pManager.WIFI_P2P_STATE_ENABLED
                        Log.d(TAG, "P2P state: ${if (isWifiP2pEnabled) "ENABLED" else "DISABLED"}")
                        sendEvent("stateChanged", mapOf("enabled" to isWifiP2pEnabled))
                    }

                    // ── 2. Peers changed ──────────────────────────────────
                    WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                        Log.d(TAG, "Peers changed — requesting peer list")
                        if (hasWifiPermission()) {
                            manager?.requestPeers(channel) { peers ->
                                onPeersAvailable(peers)
                            }
                        }
                    }

                    // ── 3. Connection changed ─────────────────────────────
                    WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                        val networkInfo = getNetworkInfo(intent)
                        if (networkInfo?.isConnected == true) {
                            Log.d(TAG, "Wi-Fi P2P connected — requesting connection info")
                            manager?.requestConnectionInfo(channel) { info ->
                                onConnectionInfoAvailable(info)
                            }
                        } else {
                            Log.d(TAG, "Wi-Fi P2P disconnected")
                            isConnected = false
                            isGroupOwner = false
                            groupOwnerAddress = null
                            closeAllSockets()
                            sendEvent("disconnected", null)
                        }
                    }

                    // ── 4. This device changed ────────────────────────────
                    WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION -> {
                        val device = getWifiP2pDevice(intent)
                        device?.let {
                            Log.d(TAG, "This device: ${it.deviceName} (${it.deviceAddress})")
                            sendEvent("thisDeviceChanged", mapOf(
                                "name" to it.deviceName,
                                "address" to it.deviceAddress,
                                "status" to deviceStatusString(it.status)
                            ))
                        }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(receiver, filter)
        }
        Log.d(TAG, "BroadcastReceiver registered for Wi-Fi P2P events")
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Peer Discovery
    // ═══════════════════════════════════════════════════════════════════

    @SuppressLint("MissingPermission")
    private fun startDiscovery(result: MethodChannel.Result) {
        if (!hasWifiPermission()) {
            Log.w(TAG, "Missing Wi-Fi permission for discovery")
            result.success(false)
            return
        }
        manager?.discoverPeers(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(TAG, "Peer discovery STARTED")
                result.success(true)
            }
            override fun onFailure(reason: Int) {
                Log.e(TAG, "Peer discovery FAILED: ${failureReason(reason)}")
                result.success(false)
            }
        }) ?: result.success(false)
    }

    private fun stopDiscovery(result: MethodChannel.Result) {
        manager?.stopPeerDiscovery(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(TAG, "Peer discovery stopped")
                result.success(true)
            }
            override fun onFailure(reason: Int) {
                Log.w(TAG, "Stop discovery failed: ${failureReason(reason)}")
                result.success(false)
            }
        }) ?: result.success(false)
    }

    private fun onPeersAvailable(peerList: WifiP2pDeviceList?) {
        val peers = peerList?.deviceList?.toList() ?: emptyList()
        discoveredPeers.clear()
        discoveredPeers.addAll(peers)
        Log.d(TAG, "Peers available: ${peers.size}")
        peers.forEach {
            Log.d(TAG, "  Peer: ${it.deviceName} (${it.deviceAddress}) status=${deviceStatusString(it.status)}")
        }
        sendEvent("peersChanged", mapOf(
            "peers" to peers.map { mapOf(
                "name" to it.deviceName,
                "address" to it.deviceAddress,
                "status" to deviceStatusString(it.status),
                "isGroupOwner" to it.isGroupOwner
            ) }
        ))
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Connect / Disconnect
    // ═══════════════════════════════════════════════════════════════════

    @SuppressLint("MissingPermission")
    private fun connectToPeer(address: String, result: MethodChannel.Result) {
        if (!hasWifiPermission()) {
            result.success(false)
            return
        }
        val config = WifiP2pConfig().apply { deviceAddress = address }
        Log.d(TAG, "Connecting to peer: $address")

        manager?.connect(channel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(TAG, "Connection initiated to $address")
                result.success(true)
            }
            override fun onFailure(reason: Int) {
                Log.e(TAG, "Connection FAILED to $address: ${failureReason(reason)}")
                result.success(false)
            }
        }) ?: result.success(false)
    }

    private fun disconnect(result: MethodChannel.Result) {
        closeAllSockets()
        manager?.removeGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(TAG, "Disconnected from P2P group")
                isConnected = false
                isGroupOwner = false
                groupOwnerAddress = null
                result.success(true)
            }
            override fun onFailure(reason: Int) {
                Log.w(TAG, "removeGroup failed: ${failureReason(reason)}")
                // Still clean up local state
                isConnected = false
                isGroupOwner = false
                result.success(false)
            }
        }) ?: result.success(false)
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Connection Info callback
    // ═══════════════════════════════════════════════════════════════════

    private fun onConnectionInfoAvailable(info: WifiP2pInfo?) {
        if (info == null) return

        isGroupOwner = info.isGroupOwner
        groupOwnerAddress = info.groupOwnerAddress?.hostAddress
        isConnected = info.groupFormed

        Log.d(TAG, "Connection info: GO=${info.isGroupOwner}, " +
                "GOAddr=$groupOwnerAddress, formed=${info.groupFormed}")

        sendEvent("connectionChanged", mapOf(
            "connected" to info.groupFormed,
            "isGroupOwner" to info.isGroupOwner,
            "groupOwnerAddress" to (groupOwnerAddress ?: "")
        ))

        if (info.groupFormed) {
            if (info.isGroupOwner) {
                startSocketServer()
            } else if (groupOwnerAddress != null) {
                startSocketClient(groupOwnerAddress!!)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun getConnectionInfo(result: MethodChannel.Result) {
        manager?.requestConnectionInfo(channel) { info ->
            result.success(mapOf(
                "connected" to (info?.groupFormed ?: false),
                "isGroupOwner" to (info?.isGroupOwner ?: false),
                "groupOwnerAddress" to (info?.groupOwnerAddress?.hostAddress ?: "")
            ))
        } ?: result.success(mapOf(
            "connected" to false,
            "isGroupOwner" to false,
            "groupOwnerAddress" to ""
        ))
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Socket Server (Group Owner side)
    // ═══════════════════════════════════════════════════════════════════

    private fun startSocketServer() {
        closeServerSocket()

        serverThread = thread(name = "WFD-Server") {
            try {
                serverSocket = ServerSocket(SOCKET_PORT).also {
                    it.reuseAddress = true
                    it.soTimeout = 0 // block indefinitely
                }
                Log.d(TAG, "Socket server listening on port $SOCKET_PORT")
                sendEvent("socketServerStarted", mapOf("port" to SOCKET_PORT))

                while (!Thread.interrupted() && serverSocket?.isClosed == false) {
                    try {
                        val client = serverSocket?.accept() ?: break
                        val addr = client.inetAddress?.hostAddress ?: "unknown"
                        Log.d(TAG, "Client socket connected: $addr")
                        synchronized(clientSockets) { clientSockets.add(client) }
                        socketStreams[addr] = client.getOutputStream()
                        sendEvent("peerSocketConnected", mapOf("address" to addr))
                        startMessageReader(client, addr)
                    } catch (e: Exception) {
                        if (!Thread.interrupted()) {
                            Log.e(TAG, "Server accept error: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Socket server error: ${e.message}")
                sendEvent("socketError", mapOf("error" to "Server: ${e.message}"))
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Socket Client (Non-Group-Owner side)
    // ═══════════════════════════════════════════════════════════════════

    private fun startSocketClient(hostAddress: String) {
        thread(name = "WFD-Client") {
            var retries = 0
            val maxRetries = 5
            while (retries < maxRetries) {
                try {
                    Log.d(TAG, "Connecting to GO at $hostAddress:$SOCKET_PORT " +
                            "(attempt ${retries + 1}/$maxRetries)")
                    val socket = Socket()
                    socket.connect(
                        InetSocketAddress(hostAddress, SOCKET_PORT),
                        SOCKET_TIMEOUT
                    )
                    Log.d(TAG, "Socket connected to GO at $hostAddress")
                    synchronized(clientSockets) { clientSockets.add(socket) }
                    socketStreams[hostAddress] = socket.getOutputStream()
                    sendEvent("peerSocketConnected", mapOf("address" to hostAddress))
                    startMessageReader(socket, hostAddress)
                    return@thread
                } catch (e: Exception) {
                    retries++
                    Log.e(TAG, "Socket connect failed (attempt $retries): ${e.message}")
                    if (retries < maxRetries) {
                        Thread.sleep(2000)
                    } else {
                        sendEvent("socketError", mapOf(
                            "error" to "Client connect failed after $maxRetries attempts"))
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Message Reader Thread (one per socket)
    // ═══════════════════════════════════════════════════════════════════

    private fun startMessageReader(socket: Socket, peerAddress: String) {
        thread(name = "WFD-Reader-$peerAddress") {
            try {
                val reader = BufferedReader(
                    InputStreamReader(socket.getInputStream(), Charsets.UTF_8)
                )
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    val msg = line ?: continue
                    Log.d(TAG, "Received from $peerAddress: ${msg.take(80)}…")
                    sendEvent("messageReceived", mapOf(
                        "message" to msg,
                        "fromAddress" to peerAddress
                    ))
                }
                Log.d(TAG, "Reader for $peerAddress: stream ended (peer closed)")
            } catch (e: Exception) {
                if (!Thread.interrupted()) {
                    Log.w(TAG, "Reader for $peerAddress ended: ${e.message}")
                }
            } finally {
                synchronized(clientSockets) { clientSockets.remove(socket) }
                socketStreams.remove(peerAddress)
                try { socket.close() } catch (_: Exception) {}
                sendEvent("peerSocketDisconnected", mapOf("address" to peerAddress))
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Send Message
    // ═══════════════════════════════════════════════════════════════════

    private fun sendMessage(
        message: String,
        targetAddress: String?,
        result: MethodChannel.Result
    ) {
        thread(name = "WFD-Send") {
            try {
                val data = (message + "\n").toByteArray(Charsets.UTF_8)
                var sent = false

                if (targetAddress != null) {
                    val os = socketStreams[targetAddress]
                    if (os != null) {
                        os.write(data); os.flush(); sent = true
                        Log.d(TAG, "Sent to $targetAddress (${data.size} bytes)")
                    } else {
                        Log.w(TAG, "No socket stream for $targetAddress")
                    }
                } else {
                    // Broadcast to all connected peers
                    for ((addr, os) in socketStreams.toMap()) {
                        try {
                            os.write(data); os.flush(); sent = true
                            Log.d(TAG, "Broadcast to $addr (${data.size} bytes)")
                        } catch (e: Exception) {
                            Log.e(TAG, "Broadcast to $addr failed: ${e.message}")
                        }
                    }
                }
                mainHandler.post { result.success(sent) }
            } catch (e: Exception) {
                Log.e(TAG, "sendMessage error: ${e.message}")
                mainHandler.post { result.success(false) }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Peers JSON (for getPeers call)
    // ═══════════════════════════════════════════════════════════════════

    private fun getPeersJson(): List<Map<String, Any>> {
        return discoveredPeers.map {
            mapOf(
                "name" to it.deviceName,
                "address" to it.deviceAddress,
                "status" to deviceStatusString(it.status),
                "isGroupOwner" to it.isGroupOwner
            )
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Cleanup
    // ═══════════════════════════════════════════════════════════════════

    private fun closeAllSockets() {
        closeServerSocket()
        synchronized(clientSockets) {
            clientSockets.forEach { try { it.close() } catch (_: Exception) {} }
            clientSockets.clear()
        }
        socketStreams.clear()
    }

    private fun closeServerSocket() {
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        serverThread?.interrupt()
        serverThread = null
    }

    fun dispose() {
        closeAllSockets()
        try {
            manager?.stopPeerDiscovery(channel, null)
            manager?.cancelConnect(channel, null)
            manager?.removeGroup(channel, null)
        } catch (_: Exception) {}
        try {
            receiver?.let { activity.unregisterReceiver(it) }
        } catch (_: Exception) {}
        receiver = null
        eventSink = null
        isInitialized = false
        isConnected = false
        discoveredPeers.clear()
        Log.d(TAG, "Wi-Fi Direct plugin disposed")
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Helpers
    // ═══════════════════════════════════════════════════════════════════

    private fun hasWifiPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                activity, Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(
                activity, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun sendEvent(type: String, data: Map<String, Any?>?) {
        mainHandler.post {
            val event = mutableMapOf<String, Any?>("type" to type)
            if (data != null) event.putAll(data)
            try {
                eventSink?.success(event)
            } catch (e: Exception) {
                Log.w(TAG, "sendEvent($type) failed: ${e.message}")
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun getNetworkInfo(intent: Intent): NetworkInfo? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(
                WifiP2pManager.EXTRA_NETWORK_INFO,
                NetworkInfo::class.java
            )
        } else {
            intent.getParcelableExtra(WifiP2pManager.EXTRA_NETWORK_INFO)
        }
    }

    @Suppress("DEPRECATION")
    private fun getWifiP2pDevice(intent: Intent): WifiP2pDevice? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(
                WifiP2pManager.EXTRA_WIFI_P2P_DEVICE,
                WifiP2pDevice::class.java
            )
        } else {
            intent.getParcelableExtra(WifiP2pManager.EXTRA_WIFI_P2P_DEVICE)
        }
    }

    private fun deviceStatusString(status: Int): String = when (status) {
        WifiP2pDevice.AVAILABLE -> "available"
        WifiP2pDevice.INVITED -> "invited"
        WifiP2pDevice.CONNECTED -> "connected"
        WifiP2pDevice.FAILED -> "failed"
        WifiP2pDevice.UNAVAILABLE -> "unavailable"
        else -> "unknown"
    }

    private fun failureReason(reason: Int): String = when (reason) {
        WifiP2pManager.P2P_UNSUPPORTED -> "P2P_UNSUPPORTED"
        WifiP2pManager.ERROR -> "ERROR"
        WifiP2pManager.BUSY -> "BUSY"
        else -> "UNKNOWN($reason)"
    }
}
