import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../data/family_api_service.dart';
import '../providers/family_providers.dart';

/// Global popup: when a family admin posts an important message,
/// show it on any screen until the member acknowledges it.
class FamilyNoticePopup extends StatefulWidget {
  const FamilyNoticePopup({super.key, this.enabled = true});

  final bool enabled;

  @override
  State<FamilyNoticePopup> createState() => _FamilyNoticePopupState();
}

class _FamilyNoticePopupState extends State<FamilyNoticePopup> {
  final _shownIds = <String>{};
  List<Map<String, dynamic>> _queue = const [];
  int _index = 0;
  bool _open = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUnread();
      _timer = Timer.periodic(const Duration(seconds: 25), (_) => _loadUnread());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    if (!widget.enabled || _busy || _open || !mounted) return;
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/family/messages')) return;

    try {
      final session = context.read<FamilySessionProvider>();
      if (session.families.isEmpty) await session.loadMine();
      if (!mounted) return;
      final families = session.families;
      if (families.isEmpty) return;

      final api = context.read<FamilyApiService>();
      final batches = await Future.wait(
        families.map((family) async {
          try {
            final res = await api.listFamilyNotices(family.id);
            final data = res.data is Map
                ? Map<String, dynamic>.from(res.data as Map)
                : <String, dynamic>{};
            final list =
                (data['notices'] is List) ? data['notices'] as List : const [];
            return list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .where(
                  (n) =>
                      n['isRead'] != true &&
                      !_shownIds.contains(n['id']?.toString() ?? ''),
                )
                .map(
                  (n) => {
                    ...n,
                    'familyId': family.id,
                    'familyName': family.name,
                  },
                )
                .toList();
          } catch (_) {
            return <Map<String, dynamic>>[];
          }
        }),
      );

      final unread = batches.expand((e) => e).toList()
        ..sort((a, b) {
          final ta = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });

      if (unread.isEmpty || !mounted) return;
      for (final n in unread) {
        final id = n['id']?.toString();
        if (id != null) _shownIds.add(id);
      }
      setState(() {
        _queue = unread;
        _index = 0;
        _open = true;
      });
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _NoticeDialog(
            notice: _queue[_index],
            index: _index,
            total: _queue.length,
            onCloseAll: () => _closeAll(ctx),
            onNext: () => _goNext(ctx),
          ),
        );
      }
    } catch (_) {
      // Sidebar poll still works.
    }
  }

  Future<void> _markQueueRead() async {
    final api = context.read<FamilyApiService>();
    final byFamily = <String, List<String>>{};
    for (final notice in _queue) {
      final familyId = notice['familyId']?.toString() ?? '';
      final id = notice['id']?.toString() ?? '';
      if (familyId.isEmpty || id.isEmpty) continue;
      byFamily.putIfAbsent(familyId, () => []).add(id);
    }
    await Future.wait(
      byFamily.entries.map((e) async {
        try {
          await api.markFamilyNoticesRead(e.key, noticeIds: e.value);
        } catch (_) {}
      }),
    );
    if (mounted) {
      context.read<FamilyNoticesUnreadProvider>().refresh();
    }
  }

  Future<void> _closeAll(BuildContext dialogContext) async {
    _busy = true;
    Navigator.of(dialogContext).pop();
    try {
      await _markQueueRead();
    } finally {
      if (mounted) {
        setState(() {
          _queue = const [];
          _index = 0;
          _open = false;
        });
      } else {
        _open = false;
      }
      _busy = false;
    }
  }

  Future<void> _goNext(BuildContext dialogContext) async {
    if (_index < _queue.length - 1) {
      Navigator.of(dialogContext).pop();
      setState(() => _index += 1);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _NoticeDialog(
          notice: _queue[_index],
          index: _index,
          total: _queue.length,
          onCloseAll: () => _closeAll(ctx),
          onNext: () => _goNext(ctx),
        ),
      );
    } else {
      await _closeAll(dialogContext);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NoticeDialog extends StatelessWidget {
  const _NoticeDialog({
    required this.notice,
    required this.index,
    required this.total,
    required this.onCloseAll,
    required this.onNext,
  });

  final Map<String, dynamic> notice;
  final int index;
  final int total;
  final VoidCallback onCloseAll;
  final VoidCallback onNext;

  String _when(dynamic value) {
    if (value == null) return '';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return '';
    return DateFormat('d MMM yyyy · HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final author = notice['author'];
    final authorName = author is Map
        ? (author['name']?.toString() ?? 'Family admin')
        : 'Family admin';
    final body = notice['body']?.toString() ?? '';
    final location = notice['location']?.toString() ?? '';
    final image = mediaUrl(notice['imagePath']?.toString());
    final familyName = notice['familyName']?.toString() ?? 'Family';
    final when = _when(notice['createdAt']);
    final hasMore = total > 1 && index < total - 1;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        children: [
          Icon(Icons.forum_outlined, color: AppTheme.emerald600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important family message',
                  style: AppTheme.body(weight: FontWeight.w800, size: 16),
                ),
                Text(
                  total > 1 ? '$familyName · ${index + 1} of $total' : familyName,
                  style: AppTheme.body(size: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCloseAll,
            icon: const Icon(Icons.close, color: Color(0xFFDC2626)),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                when.isEmpty ? authorName : '$authorName · $when',
                style: AppTheme.body(size: 11, color: AppTheme.muted),
              ),
              const SizedBox(height: 8),
              Text(body, style: AppTheme.body(size: 14)),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: AppTheme.emerald600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        location,
                        style: AppTheme.body(size: 12, color: AppTheme.mutedSoft),
                      ),
                    ),
                  ],
                ),
              ],
              if (image != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    image,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (hasMore) ...[
          OutlinedButton(
            onPressed: onCloseAll,
            child: const Text('Close all', style: TextStyle(color: Colors.black)),
          ),
          FilledButton(
            onPressed: onNext,
            child: const Text('Next'),
          ),
        ] else
          FilledButton(
            onPressed: onCloseAll,
            child: const Text('Got it'),
          ),
      ],
    );
  }
}
