import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});
  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  String? _filterCategory;
  List<CampusLocation> _locations = [];

  // Default campus center – adjust to your campus coordinates
  static const _defaultCenter = LatLng(17.3850, 78.4867);

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final state = Provider.of<AppState>(context, listen: false);
    final locs = await state.firebase.getCampusLocations();
    if (!mounted) return;
    setState(() {
      _locations = locs;
      _buildMarkers();
    });
  }

  void _buildMarkers() {
    _markers.clear();
    final filtered = _filterCategory != null
        ? _locations.where((l) => l.category == _filterCategory)
        : _locations;

    for (final loc in filtered) {
      _markers.add(Marker(
        markerId: MarkerId(loc.id),
        position: LatLng(loc.lat, loc.lng),
        infoWindow: InfoWindow(
          title: loc.name,
          snippet: '${loc.category} • ${loc.description}',
        ),
        icon: _markerColor(loc.category),
      ));
    }
  }

  BitmapDescriptor _markerColor(String category) {
    switch (category.toLowerCase()) {
      case 'academic': return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'food': return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'sports': return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'hostel': return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      case 'library': return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      case 'admin': return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'transport': return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      default: return BitmapDescriptor.defaultMarker;
    }
  }

  static const _categories = [
    'academic', 'food', 'sports', 'hostel', 'library', 'admin', 'transport', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

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
            onSelected: (v) {
              setState(() {
                _filterCategory = v.isEmpty ? null : v;
                _buildMarkers();
              });
            },
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
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 16,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) => _mapController = c,
          ),
          // Bottom list overlay
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white.withValues(alpha: 0.95)],
                ),
              ),
              child: _locations.isEmpty
                  ? const Center(child: Text('No campus locations added yet'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 12, bottom: 12),
                      itemCount: (_filterCategory != null
                              ? _locations.where((l) => l.category == _filterCategory)
                              : _locations)
                          .length,
                      itemBuilder: (ctx, i) {
                        final filtered = (_filterCategory != null
                                ? _locations.where((l) => l.category == _filterCategory)
                                : _locations)
                            .toList();
                        final loc = filtered[i];
                        return GestureDetector(
                          onTap: () {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLng(LatLng(loc.lat, loc.lng)),
                            );
                          },
                          child: Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
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
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(loc.category.toUpperCase(),
                                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(loc.description,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
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

  void _showAddLocationSheet(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    String category = 'academic';
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                const Text('Add Campus Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: _categories.map((c) => DropdownMenuItem(
                      value: c, child: Text(c[0].toUpperCase() + c.substring(1)))).toList(),
                  onChanged: (v) => setModalState(() => category = v!),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: latCtrl, keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder())),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(controller: lngCtrl, keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder())),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Tip: Use your current GPS coordinates or find them on Google Maps',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final lat = double.tryParse(latCtrl.text) ?? _defaultCenter.latitude;
                      final lng = double.tryParse(lngCtrl.text) ?? _defaultCenter.longitude;
                      state.firebase.addCampusLocation({
                        'name': nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'category': category,
                        'latitude': lat,
                        'longitude': lng,
                        'added_by': state.currentUser!.uid,
                      });
                      Navigator.pop(ctx);
                      _loadLocations();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
