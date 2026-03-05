import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String? _filterType;

  static const eventTypes = [
    'workshop', 'hackathon', 'seminar', 'sports', 'cultural', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.filter),
            onSelected: (v) => setState(() => _filterType = v.isEmpty ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All Events')),
              ...eventTypes.map((t) => PopupMenuItem(
                  value: t,
                  child: Text(t[0].toUpperCase() + t.substring(1)))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, state),
        icon: const Icon(LucideIcons.calendarPlus),
        label: const Text('Create Event'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CampusEvent>>(
        stream: state.firebase.getEventsStream(type: _filterType),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.calendar, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No events found', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: events.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (ctx, i) => _EventCard(event: events[i]),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, AppState state) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final maxCapCtrl = TextEditingController(text: '100');
    String type = 'workshop';
    DateTime? startDate;
    DateTime? endDate;
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
                const Text('Create Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Event Title *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: eventTypes.map((t) =>
                      DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: maxCapCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Capacity', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime(2030));
                          if (!ctx.mounted) return;
                          if (date != null) {
                            final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                            setModalState(() {
                              startDate = DateTime(date.year, date.month, date.day, time?.hour ?? 9, time?.minute ?? 0);
                            });
                          }
                        },
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: Text(startDate != null ? DateFormat.yMd().add_jm().format(startDate!) : 'Start Date/Time'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime(2030));
                          if (!ctx.mounted) return;
                          if (date != null) {
                            final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                            setModalState(() {
                              endDate = DateTime(date.year, date.month, date.day, time?.hour ?? 17, time?.minute ?? 0);
                            });
                          }
                        },
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: Text(endDate != null ? DateFormat.yMd().add_jm().format(endDate!) : 'End Date/Time'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      final data = <String, dynamic>{
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'organizer_id': state.currentUser!.uid,
                        'organizer_username': state.currentUser!.username,
                        'type': type,
                        'location': locationCtrl.text.trim(),
                        'max_capacity': int.tryParse(maxCapCtrl.text) ?? 100,
                      };
                      if (startDate != null) data['start_time'] = startDate;
                      if (endDate != null) data['end_time'] = endDate;
                      state.firebase.createEvent(data);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Create Event'),
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

class _EventCard extends StatelessWidget {
  final CampusEvent event;
  const _EventCard({required this.event});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'workshop': return LucideIcons.wrench;
      case 'hackathon': return LucideIcons.code;
      case 'seminar': return LucideIcons.presentation;
      case 'sports': return LucideIcons.dumbbell;
      case 'cultural': return LucideIcons.music;
      default: return LucideIcons.calendar;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'workshop': return Colors.orange;
      case 'hackathon': return Colors.purple;
      case 'seminar': return Colors.blue;
      case 'sports': return Colors.green;
      case 'cultural': return Colors.pink;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final isRegistered = event.registeredUserIds.contains(state.currentUser?.uid);
    final isFull = event.registeredUserIds.length >= event.maxCapacity;
    final typeColor = _typeColor(event.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(_typeIcon(event.type), size: 18, color: typeColor),
                const SizedBox(width: 6),
                Text(event.type.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor, letterSpacing: 1)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: event.status == 'upcoming' ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(event.status,
                      style: TextStyle(fontSize: 11, color: event.status == 'upcoming' ? Colors.green : Colors.grey)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 4),
                Text('by ${event.organizerUsername}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(event.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                if (event.startTime != null)
                  Row(
                    children: [
                      Icon(LucideIcons.clock, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(DateFormat.yMMMd().add_jm().format(event.startTime!),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                if (event.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(event.location, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(LucideIcons.users, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${event.registeredUserIds.length}/${event.maxCapacity} registered',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const Spacer(),
                    if (!isRegistered && !isFull)
                      ElevatedButton.icon(
                        onPressed: () => state.firebase.registerForEvent(event.id, state.currentUser!.uid),
                        icon: const Icon(LucideIcons.checkCircle, size: 16),
                        label: const Text('Register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    if (isRegistered)
                      OutlinedButton.icon(
                        onPressed: () => state.firebase.unregisterFromEvent(event.id, state.currentUser!.uid),
                        icon: const Icon(Icons.check, size: 16, color: Colors.green),
                        label: const Text('Registered'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    if (isFull && !isRegistered)
                      const Chip(label: Text('Full', style: TextStyle(fontSize: 12)),
                          backgroundColor: Colors.red, labelStyle: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
