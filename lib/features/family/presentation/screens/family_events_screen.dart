import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';

const _kinds = ['birthday', 'anniversary', 'event'];

class FamilyEventsScreen extends StatefulWidget {
  const FamilyEventsScreen({super.key});

  @override
  State<FamilyEventsScreen> createState() => _FamilyEventsScreenState();
}

class _FamilyEventsScreenState extends State<FamilyEventsScreen> {
  List<Map<String, dynamic>> _events = const [];
  List<FamilyMember> _members = const [];
  bool _loading = true;
  bool _canAdd = true;
  String? _error;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime? _eventDate(Map<String, dynamic> e) {
    final raw = e['eventDate'] ?? e['event_date'] ?? e['date'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _kind(Map<String, dynamic> e) =>
      (e['kind'] ?? e['type'] ?? 'event').toString().toLowerCase();

  List<Map<String, dynamic>> get _forSelected {
    final day = _selectedDay;
    if (day == null) return const [];
    return _events.where((e) {
      final d = _eventDate(e);
      if (d == null) return false;
      return d.month == day.month && d.day == day.day;
    }).toList();
  }

  List<Map<String, dynamic>> get _upcoming {
    final now = DateTime.now();
    final ranked = [..._events]..sort((a, b) {
        final da = _eventDate(a);
        final db = _eventDate(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        final na = DateTime(now.year, da.month, da.day);
        final nb = DateTime(now.year, db.month, db.day);
        final aa = na.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, da.month, da.day)
            : na;
        final bb = nb.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, db.month, db.day)
            : nb;
        return aa.compareTo(bb);
      });
    return ranked.take(6).toList();
  }

  Future<void> _load() async {
    final session = context.read<FamilySessionProvider>();
    if (session.familyId == null) await session.loadMine();
    if (!mounted) return;
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
      final api = context.read<FamilyApiService>();
      final results = await Future.wait([
        api.listFamilyEvents(familyId),
        api.listFamilyMembers(familyId),
      ]);
      final data = results[0].data;
      List list = const [];
      var canAdd = true;
      if (data is Map) {
        if (data['events'] is List) list = data['events'] as List;
        if (data['canAdd'] == false) canAdd = false;
      } else if (data is List) {
        list = data;
      }
      final mdata = results[1].data;
      List mlist = const [];
      if (mdata is Map && mdata['members'] is List) {
        mlist = mdata['members'] as List;
      } else if (mdata is List) {
        mlist = mdata;
      }
      setState(() {
        _events = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _members = mlist
            .whereType<Map>()
            .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _canAdd = canAdd;
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    if (!_canAdd && existing == null) return;
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;

    final title = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final notes = TextEditingController(
      text: existing?['notes']?.toString() ?? '',
    );
    var kind = _kind(existing ?? const {'kind': 'event'});
    if (!_kinds.contains(kind)) kind = 'event';
    var date = _eventDate(existing ?? {}) ?? (_selectedDay ?? DateTime.now());
    var repeats = existing?['repeatsYearly'] == true ||
        existing?['repeats_yearly'] == true ||
        kind == 'birthday' ||
        kind == 'anniversary';
    String? memberId =
        (existing?['memberId'] ?? existing?['member_id'])?.toString();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.canvas,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Add event' : 'Edit event',
                  style: AppTheme.display(size: 20),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in _kinds)
                      ChoiceChip(
                        label: Text(k[0].toUpperCase() + k.substring(1)),
                        selected: kind == k,
                        onSelected: (_) => setLocal(() {
                          kind = k;
                          if (k == 'birthday' || k == 'anniversary') {
                            repeats = true;
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeats yearly'),
                  value: repeats,
                  onChanged: (v) => setLocal(() => repeats = v),
                ),
                DropdownButtonFormField<String?>(
                  value: memberId,
                  decoration: const InputDecoration(labelText: 'Member'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final m in _members)
                      DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: (v) => setLocal(() => memberId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (existing != null)
                      TextButton(
                        onPressed: () async {
                          final id = (existing['id'] ?? '').toString();
                          await context
                              .read<FamilyApiService>()
                              .deleteFamilyEvent(familyId, id);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(existing == null ? 'Create' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final payload = {
      'title': title.text.trim().isEmpty ? kind : title.text.trim(),
      'kind': kind,
      'eventDate': DateFormat('yyyy-MM-dd').format(date),
      'repeatsYearly': repeats,
      'notes': notes.text.trim(),
      if (memberId != null) 'memberId': memberId,
    };
    try {
      final api = context.read<FamilyApiService>();
      if (existing == null) {
        await api.createFamilyEvent(familyId, payload);
      } else {
        await api.updateFamilyEvent(
          familyId,
          (existing['id'] ?? '').toString(),
          payload,
        );
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Color _kindColor(String kind) {
    return switch (kind) {
      'birthday' => const Color(0xFFEC4899),
      'anniversary' => const Color(0xFFF59E0B),
      _ => const Color(0xFF0EA5E9),
    };
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;

    return FtPage(
      title: 'Events',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      floatingActionButton: _canAdd
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
              backgroundColor: AppTheme.forest,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: context.pagePadding,
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() {
                          _month = DateTime(_month.year, _month.month - 1);
                        }),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat.yMMMM().format(_month),
                          textAlign: TextAlign.center,
                          style: AppTheme.display(size: 18),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _month = DateTime(_month.year, _month.month + 1);
                        }),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in _kinds)
                        Chip(
                          backgroundColor:
                              _kindColor(k).withValues(alpha: 0.14),
                          side: BorderSide(
                            color: _kindColor(k).withValues(alpha: 0.45),
                          ),
                          avatar: CircleAvatar(
                            backgroundColor: _kindColor(k),
                            radius: 6,
                          ),
                          label: Text(
                            '${k[0].toUpperCase()}${k.substring(1)} · ${_events.where((e) => _kind(e) == k).length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _kindColor(k).withValues(alpha: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderSoft),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (final d in const [
                              'S',
                              'M',
                              'T',
                              'W',
                              'T',
                              'F',
                              'S',
                            ])
                              Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: AppTheme.body(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: firstWeekday + daysInMonth,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                          itemBuilder: (_, i) {
                            if (i < firstWeekday) {
                              return const SizedBox.shrink();
                            }
                            final day = i - firstWeekday + 1;
                            final date =
                                DateTime(_month.year, _month.month, day);
                            final dayEvents = _events.where((e) {
                              final d = _eventDate(e);
                              return d != null &&
                                  d.month == date.month &&
                                  d.day == date.day;
                            }).toList();
                            final selected = _selectedDay != null &&
                                _selectedDay!.year == date.year &&
                                _selectedDay!.month == date.month &&
                                _selectedDay!.day == date.day;
                            return InkWell(
                              onTap: () => setState(() => _selectedDay = date),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.forest.withValues(alpha: 0.12)
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$day',
                                      style: AppTheme.body(
                                        size: 12,
                                        weight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    if (dayEvents.isNotEmpty)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          for (final e
                                              in dayEvents.take(3))
                                            Container(
                                              width: 5,
                                              height: 5,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _kindColor(_kind(e)),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _selectedDay == null
                        ? 'Selected day'
                        : DateFormat.MMMEd().format(_selectedDay!),
                    style: AppTheme.body(weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (_forSelected.isEmpty)
                    Text(
                      'No events on this day',
                      style: AppTheme.body(color: AppTheme.muted, size: 13),
                    ),
                  ..._forSelected.map((e) {
                    final kind = _kind(e);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _kindColor(kind).withValues(alpha: 0.15),
                          child: Icon(
                            Icons.event,
                            color: _kindColor(kind),
                            size: 18,
                          ),
                        ),
                        title: Text(e['title']?.toString() ?? 'Event'),
                        subtitle: Text(
                          [
                            kind,
                            _eventDate(e) == null
                                ? ''
                                : DateFormat.yMMMd().format(_eventDate(e)!),
                          ].where((x) => x.isNotEmpty).join(' · '),
                        ),
                        onTap: () => _openEditor(existing: e),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  Text(
                    'Coming up',
                    style: AppTheme.body(weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ..._upcoming.map((e) {
                    final d = _eventDate(e);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.celebration_outlined,
                        color: _kindColor(_kind(e)),
                      ),
                      title: Text(e['title']?.toString() ?? 'Event'),
                      subtitle: Text(
                        d == null ? '' : DateFormat.MMMd().format(d),
                      ),
                      onTap: () => _openEditor(existing: e),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
