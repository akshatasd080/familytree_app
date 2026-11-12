import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';
import '../providers/family_providers.dart';

class FamilyEventsScreen extends StatefulWidget {
  const FamilyEventsScreen({super.key});

  @override
  State<FamilyEventsScreen> createState() => _FamilyEventsScreenState();
}

class _FamilyEventsScreenState extends State<FamilyEventsScreen> {
  List<Map<String, dynamic>> _events = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<FamilySessionProvider>();
    if (session.familyId == null) await session.loadMine();
    final familyId = session.familyId;
    if (familyId == null) {
      setState(() {
        _loading = false;
        _error = 'No family';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await context.read<FamilyApiService>().listFamilyEvents(familyId);
      final data = res.data;
      List list = const [];
      if (data is Map && data['events'] is List) {
        list = data['events'] as List;
      } else if (data is List) {
        list = data;
      }
      _events = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final title = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat.yMMMd().format(date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    initialDate: date,
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<FamilyApiService>().createFamilyEvent(familyId, {
        'title': title.text.trim(),
        'date': date.toIso8601String(),
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FtPage(
      title: 'Events',
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: AppTheme.forest,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: context.pagePadding,
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: Text('No events yet')),
                    ),
                  ..._events.map((e) {
                    final id = (e['id'] ?? '').toString();
                    final familyId =
                        context.read<FamilySessionProvider>().familyId!;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(
                          e['title']?.toString() ?? 'Event',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          (e['date'] ?? e['event_date'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await context
                                .read<FamilyApiService>()
                                .deleteFamilyEvent(familyId, id);
                            _load();
                          },
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
