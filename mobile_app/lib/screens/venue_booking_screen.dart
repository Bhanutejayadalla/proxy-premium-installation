import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';

class VenueBookingScreen extends StatefulWidget {
  const VenueBookingScreen({super.key});
  @override
  State<VenueBookingScreen> createState() => _VenueBookingScreenState();
}

class _VenueBookingScreenState extends State<VenueBookingScreen> {
  String? _filterType;

  static const _sportTypes = [
    'basketball', 'football', 'tennis', 'badminton',
    'cricket', 'volleyball', 'gym', 'pool', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Venues'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.filter),
            onSelected: (v) => setState(() => _filterType = v.isEmpty ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All Venues')),
              ..._sportTypes.map((t) => PopupMenuItem(
                  value: t, child: Text(t[0].toUpperCase() + t.substring(1)))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVenueSheet(context, state),
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Venue'),
      ),
      body: StreamBuilder<List<Venue>>(
        stream: state.firebase.getVenuesStream(type: _filterType),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final venues = snap.data ?? [];
          if (venues.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.dumbbell, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No venues yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Tap "Add Venue" below to add one'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: venues.length,
            itemBuilder: (ctx, i) => _VenueCard(venue: venues[i]),
          );
        },
      ),
    );
  }

  void _showAddVenueSheet(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final amenitiesCtrl = TextEditingController();
    String type = 'basketball';
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Sports Venue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Venue Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Sport Type', border: OutlineInputBorder()),
                  items: _sportTypes.map((t) => DropdownMenuItem(
                      value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                  onChanged: (v) => setModal(() => type = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'Location / Building', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: amenitiesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Amenities (comma separated)',
                        hintText: 'Lights, Changing Room, Parking',
                        border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final amenities = amenitiesCtrl.text
                          .split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList();
                      await state.firebase.addVenue({
                        'name': nameCtrl.text.trim(),
                        'type': type,
                        'location': locationCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'amenities': amenities,
                        'added_by': state.currentUser!.uid,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Venue added!')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Add Venue'),
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

// ─── Venue Card ───────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  final Venue venue;
  const _VenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (venue.imageUrl != null && venue.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(venue.imageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.dumbbell, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(venue.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(venue.type.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ],
                ),
                if (venue.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(venue.location, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ],
                if (venue.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(venue.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (venue.amenities.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: venue.amenities.map((a) =>
                      Chip(
                        label: Text(a, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      )).toList(),
                  ),
                ],
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showBookingDialog(context, state, venue),
                        icon: const Icon(LucideIcons.calendarCheck, size: 16),
                        label: const Text('Book Slot'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showBookings(context, state, venue),
                      icon: const Icon(LucideIcons.list, size: 16),
                      label: const Text('Bookings'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDialog(BuildContext context, AppState state, Venue venue) {
    DateTime? date;
    String timeSlot = '09:00-10:00';
    final maxPlayersCtrl = TextEditingController(text: '10');
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    final timeSlots = [
      '06:00-07:00', '07:00-08:00', '08:00-09:00', '09:00-10:00',
      '10:00-11:00', '11:00-12:00', '14:00-15:00', '15:00-16:00',
      '16:00-17:00', '17:00-18:00', '18:00-19:00', '19:00-20:00',
    ];

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
                Text('Book ${venue.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx, firstDate: DateTime.now(), lastDate: DateTime(2030));
                    if (picked != null) setModalState(() => date = picked);
                  },
                  icon: const Icon(LucideIcons.calendar, size: 16),
                  label: Text(date != null ? DateFormat.yMMMd().format(date!) : 'Select Date'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: timeSlot,
                  decoration: const InputDecoration(labelText: 'Time Slot', border: OutlineInputBorder()),
                  items: timeSlots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setModalState(() => timeSlot = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: maxPlayersCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max Players', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (date == null) return;
                      state.firebase.createVenueBooking({
                        'venue_id': venue.id,
                        'venue_name': venue.name,
                        'booker_id': state.currentUser!.uid,
                        'booker_username': state.currentUser!.username,
                        'date': date,
                        'time_slot': timeSlot,
                        'sport': venue.type,
                        'max_players': int.tryParse(maxPlayersCtrl.text) ?? 10,
                        'player_ids': [state.currentUser!.uid],
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking confirmed!')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Confirm Booking'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBookings(BuildContext context, AppState state, Venue venue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Bookings for ${venue.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<List<VenueBooking>>(
                stream: state.firebase.getVenueBookingsStream(venue.id),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final bookings = snap.data ?? [];
                  if (bookings.isEmpty) {
                    return const Center(child: Text('No bookings yet'));
                  }
                  return ListView.builder(
                    itemCount: bookings.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (ctx, i) {
                      final b = bookings[i];
                      final canJoin = !b.playerIds.contains(state.currentUser?.uid) &&
                          b.playerIds.length < b.maxPlayers;
                      return ListTile(
                        leading: const Icon(LucideIcons.calendar),
                        title: Text('${b.date != null ? DateFormat.yMMMd().format(b.date!) : "TBD"} • ${b.timeSlot}'),
                        subtitle: Text('${b.bookerUsername} • ${b.playerIds.length}/${b.maxPlayers} players'),
                        trailing: canJoin
                            ? TextButton(
                                onPressed: () => state.firebase.joinVenueBooking(b.id, state.currentUser!.uid),
                                child: const Text('Join'),
                              )
                            : b.playerIds.contains(state.currentUser?.uid)
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const Text('Full', style: TextStyle(color: Colors.red)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
