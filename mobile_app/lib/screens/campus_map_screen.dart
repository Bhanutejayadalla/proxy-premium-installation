import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';
import '../services/routing_service.dart';

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
  String? _filterCategory;

  // ── Search ──
  String _searchQuery = '';
  bool _showSearchResults = false;

  // ── Distance / Routing ──
  DistanceMode _distanceMode = DistanceMode.none;
  CampusLocation? _selectedA; // origin  (or single selection for myLocation mode)
  CampusLocation? _selectedB; // destination (only for placeToPlace)
  RouteResult? _routeResult;
  bool _routeLoading = false;
  LatLng? _currentPosition;

  // Default campus center
  static const _defaultCenter = LatLng(17.3850, 78.4867);

  static const _categories = [
    'academic', 'food', 'sports', 'hostel', 'library', 'admin', 'transport', 'other',
  ];

  // ─────────────────────────── Lifecycle ───────────────────────────

  @override
  void initState() {
    super.initState();
    _loadLocations();
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

  Future<void> _acquireGPS() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  // ─────────────────────────── Filtering ──────────────────────────

  List<CampusLocation> get _filtered {
    var list = _filterCategory != null
        ? _locations.where((l) => l.category == _filterCategory).toList()
        : List<CampusLocation>.from(_locations);
    return list;
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

    // Zoom to fit route
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
        // Start fresh selection
        setState(() {
          _selectedA = loc;
          _selectedB = null;
          _routeResult = null;
        });
      } else {
        // Second selection
        setState(() {
          _selectedB = loc;
          _routeResult = null;
        });
        _calculateRoute();
      }
    } else {
      // No distance mode → show info
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
      default: return LucideIcons.mapPin;
    }
  }

  bool _isSelected(CampusLocation loc) =>
      loc.id == _selectedA?.id || loc.id == _selectedB?.id;

  // ─────────────────────────── BUILD ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Add Location',
            onPressed: () => _showAddLocationSheet(context, state),
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.filter),
            onSelected: (v) => setState(() => _filterCategory = v.isEmpty ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All Categories')),
              ..._categories.map((c) => PopupMenuItem(
                  value: c, child: Text(c[0].toUpperCase() + c.substring(1)))),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // ═══════ MAP ═══════
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 16,
              onTap: (_, __) {
                if (_showSearchResults) setState(() => _showSearchResults = false);
              },
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
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                        ),
                      ),
                    ),
                  ],
                ),
              // Location markers
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
                            LucideIcons.mapPin,
                            color: selected ? color : _markerColor(loc.category),
                            size: selected ? 38 : 34,
                            shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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

          // ═══════ SEARCH BAR ═══════
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
                // Autocomplete results
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
                          subtitle: Text(loc.category[0].toUpperCase() + loc.category.substring(1),
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

          // ═══════ DISTANCE MODE SELECTOR ═══════
          Positioned(
            top: 72,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _DistanceModeChip(
                  label: 'My Location → Place',
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
                const SizedBox(width: 8),
                _DistanceModeChip(
                  label: 'Place → Place',
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
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearRoute,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Icon(LucideIcons.x, size: 18, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ═══════ INSTRUCTION HINT ═══════
          if (_distanceMode != DistanceMode.none && _routeResult == null && !_routeLoading)
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

          // ═══════ ROUTE LOADING ═══════
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

          // ═══════ ROUTE RESULT CARD ═══════
          if (_routeResult != null)
            Positioned(
              bottom: 160,
              left: 16,
              right: 16,
              child: Container(
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
                                    ? 'My Location → ${_selectedA?.name ?? ''}'
                                    : '${_selectedA?.name ?? ''} → ${_selectedB?.name ?? ''}',
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
                        _RouteStatChip(
                          icon: LucideIcons.ruler,
                          label: _routeResult!.distanceText,
                          color: color,
                        ),
                        const SizedBox(width: 12),
                        _RouteStatChip(
                          icon: LucideIcons.footprints,
                          label: _routeResult!.walkingTimeText,
                          color: color,
                        ),
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
              ),
            ),

          // ═══════ BOTTOM HORIZONTAL LOCATION LIST ═══════
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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
                        'No campus locations added yet.\nTap + to add one.',
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
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(loc.category.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 10, color: color, fontWeight: FontWeight.w600)),
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
            ),
          ),
        ],
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
            Text(loc.category.toUpperCase(),
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
            // Quick-route buttons
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

  void _showAddLocationSheet(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    String category = 'academic';
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    // Pre-fill GPS if available
    if (_currentPosition != null) {
      latCtrl.text = _currentPosition!.latitude.toStringAsFixed(6);
      lngCtrl.text = _currentPosition!.longitude.toStringAsFixed(6);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Campus Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c[0].toUpperCase() + c.substring(1))))
                      .toList(),
                  onChanged: (v) => setModalState(() => category = v!),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: latCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Latitude', border: OutlineInputBorder())),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: lngCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Longitude', border: OutlineInputBorder())),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    _currentPosition != null
                        ? 'Pre-filled with your current GPS coordinates'
                        : 'Tip: Use your GPS coordinates or find them on Google Maps',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final lat =
                          double.tryParse(latCtrl.text) ?? _defaultCenter.latitude;
                      final lng =
                          double.tryParse(lngCtrl.text) ?? _defaultCenter.longitude;
                      state.firebase.addCampusLocation({
                        'name': nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'category': category,
                        'lat': lat,
                        'lng': lng,
                        'added_by': state.currentUser!.uid,
                      });
                      Navigator.pop(ctx);
                      _loadLocations();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Add Location'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Helper Widgets ───────────────────────

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
