import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';
import '../services/routing_service.dart';
import 'user_detail_screen.dart';
import 'chat_detail_screen.dart';

// ─────────────────────────────────────────────
//  DISTANCE MODE
// ─────────────────────────────────────────────
enum DistanceMode { none, myLocationToPlace, placeToPlace }

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});
  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // ── Data ──
  List<CampusLocation> _locations = [];
  List<UserMarker> _userMarkers = [];
  // Nearby connections: each item is {'user': AppUser, 'mode': String, 'distanceKm': double}
  List<Map<String, dynamic>> _nearbyConnections = [];
  String? _filterCategory;
  bool _showConnections = true;

  // ── Search ──
  String _searchQuery = '';
  bool _showSearchResults = false;

  // ── Distance / Routing ──
  DistanceMode _distanceMode = DistanceMode.none;
  CampusLocation? _selectedA;
  CampusLocation? _selectedB;
  RouteResult? _routeResult;
  bool _routeLoading = false;
  LatLng? _currentPosition;

  // ── Edge cases ──
  bool _gpsPermissionDenied = false;
  bool _loadingConnections = false;

  // Default campus center
  static const _defaultCenter = LatLng(17.3850, 78.4867);

  static const _categories = [
    'academic', 'food', 'sports', 'hostel', 'library', 'admin', 'transport', 'other',
  ];

  static const _markerCategories = [
    'study_spot', 'event_location', 'cafe', 'important_place', 'custom',
  ];

  // ─────────────────────────── Lifecycle ───────────────────────────

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _loadUserMarkers();
    _acquireGPS();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final state = Provider.of<AppState>(context, listen: false);
    final locs = await state.firebase.getCampusLocations();
    if (!mounted) return;
    setState(() => _locations = locs);
  }

  Future<void> _loadUserMarkers() async {
    final state = Provider.of<AppState>(context, listen: false);
    final markers = await state.firebase.getUserMarkers();
    if (!mounted) return;
    setState(() => _userMarkers = markers);
  }

  Future<void> _loadNearbyConnections() async {
    if (_currentPosition == null) return;
    final state = Provider.of<AppState>(context, listen: false);
    if (state.currentUser == null) return;
    setState(() => _loadingConnections = true);
    try {
      final connections = await state.firebase.getNearbyConnections(
        state.currentUser!.uid,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (!mounted) return;
      setState(() {
        _nearbyConnections = connections;
        _loadingConnections = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingConnections = false);
    }
  }

  Future<void> _acquireGPS() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _gpsPermissionDenied = true);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _gpsPermissionDenied = true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _gpsPermissionDenied = false;
      });
      // Update user location in DB & fetch nearby connections
      final state = Provider.of<AppState>(context, listen: false);
      if (state.currentUser != null) {
        await state.firebase.updateUserLocation(
          state.currentUser!.uid, pos.latitude, pos.longitude,
        );
        _loadNearbyConnections();
      }
    } catch (_) {
      if (mounted) setState(() => _gpsPermissionDenied = true);
    }
  }

  // ─────────────────────────── Filtering ──────────────────────────

  List<CampusLocation> get _filtered {
    var list = _filterCategory != null
        ? _locations.where((l) => l.category == _filterCategory).toList()
        : List<CampusLocation>.from(_locations);
    return list;
  }

  List<UserMarker> get _filteredMarkers {
    if (_filterCategory == null) return _userMarkers;
    return _userMarkers.where((m) => m.category == _filterCategory).toList();
  }

  List<CampusLocation> get _searchResults {
    if (_searchQuery.trim().isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return _locations.where((l) {
      return l.name.toLowerCase().contains(q) ||
          l.category.toLowerCase().contains(q) ||
          l.description.toLowerCase().contains(q);
    }).toList();
  }

  // ─────────────────────────── Routing ────────────────────────────

  Future<void> _calculateRoute() async {
    LatLng? from;
    LatLng? to;

    if (_distanceMode == DistanceMode.myLocationToPlace) {
      if (_currentPosition == null || _selectedA == null) return;
      from = _currentPosition!;
      to = LatLng(_selectedA!.lat, _selectedA!.lng);
    } else if (_distanceMode == DistanceMode.placeToPlace) {
      if (_selectedA == null || _selectedB == null) return;
      from = LatLng(_selectedA!.lat, _selectedA!.lng);
      to = LatLng(_selectedB!.lat, _selectedB!.lng);
    } else {
      return;
    }

    setState(() => _routeLoading = true);
    final result = await RoutingService.getRoute(from, to);
    if (!mounted) return;
    setState(() {
      _routeResult = result;
      _routeLoading = false;
    });

    if (result.polyline.length >= 2) {
      final bounds = LatLngBounds.fromPoints(result.polyline);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    }
  }

  void _clearRoute() {
    setState(() {
      _routeResult = null;
      _selectedA = null;
      _selectedB = null;
      _distanceMode = DistanceMode.none;
    });
  }

  void _onMarkerTap(CampusLocation loc, Color color) {
    if (_distanceMode == DistanceMode.myLocationToPlace) {
      setState(() {
        _selectedA = loc;
        _routeResult = null;
      });
      _calculateRoute();
    } else if (_distanceMode == DistanceMode.placeToPlace) {
      if (_selectedA == null || (_selectedA != null && _selectedB != null)) {
        setState(() {
          _selectedA = loc;
          _selectedB = null;
          _routeResult = null;
        });
      } else {
        setState(() {
          _selectedB = loc;
          _routeResult = null;
        });
        _calculateRoute();
      }
    } else {
      _showLocationInfo(context, loc, color);
    }
  }

  // ─────────────────────────── Colours & icons ────────────────────

  Color _markerColor(String category) {
    switch (category.toLowerCase()) {
      case 'academic': return Colors.blue;
      case 'food': return Colors.orange;
      case 'sports': return Colors.green;
      case 'hostel': return Colors.purple;
      case 'library': return Colors.cyan.shade700;
      case 'admin': return Colors.red;
      case 'transport': return Colors.amber.shade700;
      case 'study_spot': return Colors.orange.shade700;
      case 'event_location': return Colors.orange.shade600;
      case 'cafe': return Colors.orange.shade500;
      case 'important_place': return Colors.orange.shade800;
      case 'custom': return Colors.orange.shade400;
      default: return Colors.grey;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'academic': return LucideIcons.graduationCap;
      case 'food': return LucideIcons.utensils;
      case 'sports': return LucideIcons.dumbbell;
      case 'hostel': return LucideIcons.bed;
      case 'library': return LucideIcons.bookOpen;
      case 'admin': return LucideIcons.building;
      case 'transport': return LucideIcons.bus;
      case 'study_spot': return LucideIcons.bookMarked;
      case 'event_location': return LucideIcons.calendar;
      case 'cafe': return LucideIcons.coffee;
      case 'important_place': return LucideIcons.star;
      case 'custom': return LucideIcons.flag;
      default: return LucideIcons.mapPin;
    }
  }

  String _categoryLabel(String cat) {
    return cat.replaceAll('_', ' ').split(' ').map((w) =>
        w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  bool _isSelected(CampusLocation loc) =>
      loc.id == _selectedA?.id || loc.id == _selectedB?.id;

  // ─────────────────────────── BUILD ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final filtered = _filtered;
    final filteredMarkers = _filteredMarkers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.shield),
            tooltip: 'Privacy Settings',
            onPressed: () => _showPrivacySettings(context, state),
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.filter),
            onSelected: (v) => setState(() => _filterCategory = v.isEmpty ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All Categories')),
              ..._categories.map((c) => PopupMenuItem(
                  value: c, child: Text(_categoryLabel(c)))),
              const PopupMenuDivider(),
              ..._markerCategories.map((c) => PopupMenuItem(
                  value: c, child: Text(_categoryLabel(c)))),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? _defaultCenter,
              initialZoom: 16,
              onTap: (_, __) {
                if (_showSearchResults) setState(() => _showSearchResults = false);
              },
              onLongPress: (_, point) => _showAddMarkerDialog(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.proxi.premium',
              ),
              // Route polyline
              if (_routeResult != null && _routeResult!.polyline.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeResult!.polyline,
                      strokeWidth: _routeResult!.isRoadBased ? 5.0 : 3.0,
                      color: _routeResult!.isRoadBased
                          ? color.withValues(alpha: 0.85)
                          : Colors.grey.withValues(alpha: 0.6),
                      pattern: _routeResult!.isRoadBased
                          ? const StrokePattern.solid()
                          : StrokePattern.dashed(segments: [10, 8]),
                    ),
                  ],
                ),
              // Current position marker (blue dot)
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                        ),
                        child: const Icon(LucideIcons.user, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              // Nearby connections markers + connecting lines (color depends on connection mode)
              if (_showConnections && _nearbyConnections.isNotEmpty) ...[
                // Lines from me -> connection
                PolylineLayer(
                  polylines: _nearbyConnections.map((m) {
                    final user = m['user'] as AppUser;
                    final mode = (m['mode'] as String?) ?? 'casual';
                    final colorLine = (mode == 'formal' || mode == 'pro')
                        ? Colors.pink.shade400
                        : Colors.green.shade600;
                    return Polyline(
                      points: [
                        if (_currentPosition != null) _currentPosition!,
                        LatLng(user.locationLat!, user.locationLng!),
                      ],
                      strokeWidth: 3.0,
                      color: colorLine.withOpacity(0.9),
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: _nearbyConnections.map((m) {
                    final user = m['user'] as AppUser;
                    final mode = (m['mode'] as String?) ?? 'casual';
                    final markerColor = (mode == 'formal' || mode == 'pro')
                        ? Colors.pink.shade400
                        : Colors.green.shade600;
                    return Marker(
                      point: LatLng(user.locationLat!, user.locationLng!),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showConnectionInfo(context, user, state),
                        child: Container(
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                          ),
                          child: _buildConnectionAvatar(user, state.isFormal),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              // Campus location markers (colored by category)
              MarkerLayer(
                markers: filtered.map((loc) {
                  final selected = _isSelected(loc);
                  return Marker(
                    point: LatLng(loc.lat, loc.lng),
                    width: selected ? 52 : 40,
                    height: selected ? 52 : 40,
                    child: GestureDetector(
                      onTap: () => _onMarkerTap(loc, color),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (selected)
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: 0.2),
                                border: Border.all(color: color, width: 2),
                              ),
                            ),
                          Icon(
                            _categoryIcon(loc.category),
                            color: selected ? color : _markerColor(loc.category),
                            size: selected ? 32 : 28,
                            shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              // User custom markers (orange) — tap to view, long-press to delete if owner
              MarkerLayer(
                markers: filteredMarkers.map((m) => Marker(
                  point: LatLng(m.lat, m.lng),
                  width: 36,
                  height: 36,
                  child: GestureDetector(
                    onTap: () => _showUserMarkerInfo(context, m, color, state),
                    onLongPress: () async {
                      final isOwn = m.createdBy == state.currentUser?.uid;
                      if (!isOwn) return;
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete marker?'),
                          content: const Text('Remove this marker from the map?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await state.firebase.deleteUserMarker(m.id);
                        _loadUserMarkers();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marker deleted')),
                        );
                      }
                    },
                    child: Icon(
                      _categoryIcon(m.category),
                      color: Colors.orange.shade700,
                      size: 28,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
                    ),
                  ),
                )).toList(),
              ),
              // OSM attribution
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors',
                      onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright'))),
                ],
              ),
            ],
          ),

          // SEARCH BAR
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _showSearchResults = v.trim().isNotEmpty;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search campus locations...',
                      prefixIcon: const Icon(LucideIcons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _showSearchResults = false;
                                });
                                _searchFocus.unfocus();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final loc = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(_categoryIcon(loc.category),
                              color: _markerColor(loc.category), size: 20),
                          title: Text(loc.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(_categoryLabel(loc.category),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          onTap: () {
                            _searchCtrl.text = loc.name;
                            setState(() => _showSearchResults = false);
                            _searchFocus.unfocus();
                            _mapController.move(LatLng(loc.lat, loc.lng), 18);
                            _onMarkerTap(loc, color);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // TOGGLE & DISTANCE MODE ROW
          Positioned(
            top: 72,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ToggleChip(
                    label: 'Connections',
                    icon: LucideIcons.users,
                    active: _showConnections,
                    color: Colors.green,
                    badge: _nearbyConnections.length,
                    onTap: () => setState(() => _showConnections = !_showConnections),
                  ),
                  const SizedBox(width: 6),
                  _DistanceModeChip(
                    label: 'My Loc \u2192 Place',
                    icon: LucideIcons.navigation,
                    active: _distanceMode == DistanceMode.myLocationToPlace,
                    color: color,
                    onTap: () {
                      if (_currentPosition == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('GPS position not available')),
                        );
                        return;
                      }
                      setState(() {
                        if (_distanceMode == DistanceMode.myLocationToPlace) {
                          _clearRoute();
                        } else {
                          _clearRoute();
                          _distanceMode = DistanceMode.myLocationToPlace;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _DistanceModeChip(
                    label: 'Place \u2192 Place',
                    icon: LucideIcons.arrowLeftRight,
                    active: _distanceMode == DistanceMode.placeToPlace,
                    color: color,
                    onTap: () {
                      setState(() {
                        if (_distanceMode == DistanceMode.placeToPlace) {
                          _clearRoute();
                        } else {
                          _clearRoute();
                          _distanceMode = DistanceMode.placeToPlace;
                        }
                      });
                    },
                  ),
                  if (_distanceMode != DistanceMode.none) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _clearRoute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Icon(LucideIcons.x, size: 18, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // GPS DENIED BANNER
          if (_gpsPermissionDenied)
            Positioned(
              top: 112,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'GPS unavailable. Enable location to see nearby connections.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: _acquireGPS,
                      child: const Text('Retry', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12,
                      )),
                    ),
                  ],
                ),
              ),
            ),

          // INSTRUCTION HINT
          if (!_gpsPermissionDenied && _distanceMode != DistanceMode.none && _routeResult == null && !_routeLoading)
            Positioned(
              top: 112,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _distanceMode == DistanceMode.myLocationToPlace
                      ? 'Tap a location marker to see the route from your position'
                      : _selectedA == null
                          ? 'Tap the first location (origin)'
                          : 'Tap the second location (destination)',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // ROUTE LOADING
          if (_routeLoading)
            Positioned(
              top: 112,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('Calculating route...', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // ROUTE RESULT CARD
          if (_routeResult != null)
            Positioned(
              bottom: 160,
              left: 16,
              right: 16,
              child: _buildRouteCard(color),
            ),

          // LONG-PRESS HINT
          if (!_showSearchResults && _distanceMode == DistanceMode.none && _routeResult == null)
            Positioned(
              bottom: 152,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Long-press on map to add a marker',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ),

          // BOTTOM HORIZONTAL LOCATION LIST
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomList(filtered, color),
          ),
        ],
      ),
      // MY LOCATION FAB
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(_currentPosition!, 17);
          } else {
            _acquireGPS();
          }
        },
        child: Icon(
          _currentPosition != null ? LucideIcons.crosshair : LucideIcons.locateOff,
          color: _currentPosition != null ? color : Colors.grey,
        ),
      ),
    );
  }

  // ───────────────────── Connection Avatar ─────────────────────

  Widget _buildConnectionAvatar(AppUser conn, bool isFormal) {
    final avatar = conn.getAvatar(isFormal);
    if (avatar.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatar,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (_, __) => const Icon(LucideIcons.user, size: 18, color: Colors.white),
          errorWidget: (_, __, ___) => const Icon(LucideIcons.user, size: 18, color: Colors.white),
        ),
      );
    }
    return const Icon(LucideIcons.user, size: 18, color: Colors.white);
  }

  // ───────────────────── Route Card ────────────────────────────

  Widget _buildRouteCard(Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.navigation2, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _distanceMode == DistanceMode.myLocationToPlace
                          ? 'My Location \u2192 ${_selectedA?.name ?? ''}'
                          : '${_selectedA?.name ?? ''} \u2192 ${_selectedB?.name ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _routeResult!.isRoadBased ? 'Road-based route' : 'Straight-line estimate',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RouteStatChip(icon: LucideIcons.ruler, label: _routeResult!.distanceText, color: color),
              const SizedBox(width: 12),
              _RouteStatChip(icon: LucideIcons.footprints, label: _routeResult!.walkingTimeText, color: color),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearRoute,
                icon: Icon(LucideIcons.x, size: 14, color: Colors.grey.shade600),
                label: Text('Clear', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────── Bottom List ──────────────────────────

  Widget _buildBottomList(List<CampusLocation> filtered, Color color) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white.withValues(alpha: 0.95)],
        ),
      ),
      child: filtered.isEmpty
          ? const Center(
              child: Text(
                'No campus locations yet.\nLong-press on the map to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12, bottom: 12, top: 8),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final loc = filtered[i];
                final selected = _isSelected(loc);
                return GestureDetector(
                  onTap: () {
                    _mapController.move(LatLng(loc.lat, loc.lng), 18);
                    _onMarkerTap(loc, color);
                  },
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: selected ? Border.all(color: color, width: 2) : null,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(_categoryIcon(loc.category), size: 16, color: color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(loc.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_categoryLabel(loc.category).toUpperCase(),
                            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(loc.description,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ─────────────────────────── Bottom Sheets ──────────────────────

  void _showLocationInfo(BuildContext context, CampusLocation loc, Color color) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_categoryIcon(loc.category), color: color),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(loc.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 6),
            Text(_categoryLabel(loc.category).toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
            if (loc.floor.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Floor: ${loc.floor}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
            if (loc.openHours.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Hours: ${loc.openHours}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
            if (loc.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(loc.description),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (_currentPosition != null) {
                        setState(() {
                          _distanceMode = DistanceMode.myLocationToPlace;
                          _selectedA = loc;
                          _selectedB = null;
                          _routeResult = null;
                        });
                        _calculateRoute();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('GPS position not available')),
                        );
                      }
                    },
                    icon: const Icon(LucideIcons.navigation, size: 16),
                    label: const Text('Route Here', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(
                          'https://www.openstreetmap.org/?mlat=${loc.lat}&mlon=${loc.lng}&zoom=18'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(LucideIcons.externalLink, size: 16),
                    label: const Text('Open OSM', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Connection Info Sheet ─────────────────────────────────────

  void _showConnectionInfo(BuildContext context, AppUser conn, AppState state) {
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final avatar = conn.getAvatar(state.isFormal);
    final distText = conn.distanceKm != null
        ? '${conn.distanceKm!.toStringAsFixed(1)} km away'
        : '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green.shade100,
                  backgroundImage: avatar.isNotEmpty
                      ? CachedNetworkImageProvider(avatar)
                      : null,
                  child: avatar.isEmpty
                      ? Icon(LucideIcons.user, color: Colors.green.shade700, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(conn.fullName.isNotEmpty ? conn.fullName : conn.username,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (conn.username.isNotEmpty)
                        Text('@${conn.username}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      if (distText.isNotEmpty)
                        Text(distText,
                            style: TextStyle(color: Colors.green.shade700, fontSize: 12,
                                fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (conn.department.isNotEmpty || conn.skills.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (conn.department.isNotEmpty)
                      Text('Department: ${conn.department}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    if (conn.skills.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: conn.skills.take(5).map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => UserDetailScreen(user: conn)));
                    },
                    icon: const Icon(LucideIcons.user, size: 16),
                    label: const Text('View Profile', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          targetUser: conn.username,
                          targetUid: conn.uid,
                        ),
                      ));
                    },
                    icon: const Icon(LucideIcons.messageCircle, size: 16),
                    label: const Text('Chat', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Add Marker Dialog (Long-press) ────────────────────────────

  void _showAddMarkerDialog(LatLng point) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'custom';
    final state = Provider.of<AppState>(context, listen: false);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Text('Add Marker',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Coordinates captured automatically from your selection',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Marker Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.type, size: 18),
                    )),
                const SizedBox(height: 10),
                TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.alignLeft, size: 18),
                    )),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.tag, size: 18),
                  ),
                  items: _markerCategories
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(_categoryLabel(c))))
                      .toList(),
                  onChanged: (v) => setModalState(() => category = v!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a marker title')),
                        );
                        return;
                      }
                      await state.firebase.addUserMarker({
                        'createdBy': state.currentUser!.uid,
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'category': category,
                        'lat': point.latitude,
                        'lng': point.longitude,
                      });
                      Navigator.pop(ctx);
                      _loadUserMarkers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Marker added!')),
                      );
                    },
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: const Text('Save Marker'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── User Marker Info Sheet ─────────────────────────────────────

  void _showUserMarkerInfo(BuildContext context, UserMarker marker, Color color, AppState state) {
    final isOwn = marker.createdBy == state.currentUser?.uid;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_categoryIcon(marker.category), color: Colors.orange.shade700),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(marker.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (isOwn)
                IconButton(
                  icon: Icon(LucideIcons.trash2, color: Colors.red.shade400, size: 20),
                  onPressed: () async {
                    await state.firebase.deleteUserMarker(marker.id);
                    Navigator.pop(context);
                    _loadUserMarkers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marker deleted')),
                    );
                  },
                ),
            ]),
            const SizedBox(height: 6),
            Text(_categoryLabel(marker.category).toUpperCase(),
                style: TextStyle(color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600, fontSize: 12)),
            if (marker.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(marker.description),
            ],
            if (marker.createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Added ${_timeAgo(marker.createdAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 14),
            if (_currentPosition != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final tempLoc = CampusLocation(
                      id: marker.id,
                      name: marker.title,
                      category: marker.category,
                      description: marker.description,
                      lat: marker.lat,
                      lng: marker.lng,
                    );
                    setState(() {
                      _distanceMode = DistanceMode.myLocationToPlace;
                      _selectedA = tempLoc;
                      _selectedB = null;
                      _routeResult = null;
                    });
                    _calculateRoute();
                  },
                  icon: const Icon(LucideIcons.navigation, size: 16),
                  label: const Text('Route Here', style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  // ─── Privacy Settings Sheet ────────────────────────────────────

  void _showPrivacySettings(BuildContext context, AppState state) {
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    String sharing = state.currentUser?.locationSharing ?? 'connections';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.shield, color: color),
                  const SizedBox(width: 10),
                  const Text('Location Privacy',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Control who can see your location on the campus map',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _PrivacyOption(
                title: 'Share with Connections',
                subtitle: 'Only your connections can see you on the map',
                icon: LucideIcons.users,
                selected: sharing == 'connections',
                color: color,
                onTap: () => setModalState(() => sharing = 'connections'),
              ),
              const SizedBox(height: 8),
              _PrivacyOption(
                title: 'Hide from Map',
                subtitle: 'Nobody can see your location',
                icon: LucideIcons.eyeOff,
                selected: sharing == 'off',
                color: color,
                onTap: () => setModalState(() => sharing = 'off'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    state.firebase.updateProfile(state.currentUser!.uid, {
                      'location_sharing': sharing,
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                        sharing == 'off'
                            ? 'Location hidden from map'
                            : 'Location shared with connections',
                      )),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Privacy Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Helper Widgets ───────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final int badge;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : Colors.grey.shade700)),
            if (badge > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withValues(alpha: 0.3) : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$badge',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.white : color)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DistanceModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _DistanceModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

class _RouteStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RouteStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PrivacyOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : Colors.grey.shade500, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? color : Colors.black87,
                  )),
                  Text(subtitle, style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  )),
                ],
              ),
            ),
            if (selected)
              Icon(LucideIcons.checkCircle, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
