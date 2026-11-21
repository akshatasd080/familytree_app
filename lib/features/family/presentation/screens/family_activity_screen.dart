import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_branded_page.dart';
import '../../data/family_api_service.dart';
import '../providers/family_providers.dart';

enum _ActivityKind { notification, notice, post }

class _ActivityItem {
  const _ActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.when,
    this.subtitle,
    this.imageUrl,
    this.isRead = true,
    this.raw,
  });

  final String id;
  final _ActivityKind kind;
  final String title;
  final String? subtitle;
  final DateTime? when;
  final String? imageUrl;
  final bool isRead;
  final Map<String, dynamic>? raw;
}

class FamilyActivityScreen extends StatefulWidget {
  const FamilyActivityScreen({super.key});

  @override
  State<FamilyActivityScreen> createState() => _FamilyActivityScreenState();
}

class _FamilyActivityScreenState extends State<FamilyActivityScreen> {
  List<_ActivityItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  String _authorName(Map<String, dynamic> item) {
    final author = _asMap(item['author']);
    final user = _asMap(item['user']);
    final name = (item['authorName'] ??
            item['uploadedByName'] ??
            item['userName'] ??
            author?['name'] ??
            user?['name'] ??
            '')
        .toString()
        .trim();
    return name.isEmpty ? 'Family member' : name;
  }

  String? _postImage(Map<String, dynamic> item) => mediaUrl(
        (item['url'] ??
                item['image'] ??
                item['path'] ??
                item['file_path'] ??
                item['filePath'] ??
                item['thumbnailUrl'])
            ?.toString(),
      );

  String? _noticeImage(Map<String, dynamic> item) => mediaUrl(
        (item['imageUrl'] ??
                item['image'] ??
                item['photoUrl'] ??
                item['url'])
            ?.toString(),
      );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<FamilyApiService>();
    final session = context.read<FamilySessionProvider>();
    try {
      if (session.families.isEmpty) await session.loadMine();
      final familyId = session.familyId;

      final results = await Future.wait([
        api.listNotifications(),
        if (familyId != null) ...[
          api.listFamilyNotices(familyId),
          api.listFamilyMedia(familyId),
        ],
      ]);

      final items = <_ActivityItem>[];

      final notifData = results[0].data;
      List nList = const [];
      if (notifData is Map && notifData['notifications'] is List) {
        nList = notifData['notifications'] as List;
      } else if (notifData is List) {
        nList = notifData;
      }
      for (final raw in nList.whereType<Map>()) {
        final n = Map<String, dynamic>.from(raw);
        final id = (n['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final isRead = n['is_read'] == true || n['isRead'] == true;
        items.add(
          _ActivityItem(
            id: 'notif:$id',
            kind: _ActivityKind.notification,
            title: (n['message'] ?? n['title'] ?? 'Notice').toString(),
            when: _parseDate(
              n['createdAt'] ?? n['created_at'] ?? n['updatedAt'],
            ),
            isRead: isRead,
            raw: n,
          ),
        );
      }

      if (familyId != null && results.length >= 3) {
        final noticeData = results[1].data;
        List noticeList = const [];
        if (noticeData is Map && noticeData['notices'] is List) {
          noticeList = noticeData['notices'] as List;
        } else if (noticeData is List) {
          noticeList = noticeData;
        }
        for (final raw in noticeList.whereType<Map>()) {
          final n = Map<String, dynamic>.from(raw);
          final id = (n['id'] ?? '').toString();
          if (id.isEmpty) continue;
          final author = _authorName(n);
          final body = (n['body'] ?? n['message'] ?? n['text'] ?? '')
              .toString()
              .trim();
          items.add(
            _ActivityItem(
              id: 'notice:$id',
              kind: _ActivityKind.notice,
              title: '$author posted an important message',
              subtitle: body.isEmpty ? null : body,
              when: _parseDate(
                n['createdAt'] ?? n['created_at'] ?? n['updatedAt'],
              ),
              imageUrl: _noticeImage(n),
              isRead: n['isRead'] == true || n['is_read'] == true,
              raw: n,
            ),
          );
        }

        final mediaData = results[2].data;
        List mediaList = const [];
        if (mediaData is Map && mediaData['media'] is List) {
          mediaList = mediaData['media'] as List;
        } else if (mediaData is List) {
          mediaList = mediaData;
        }
        for (final raw in mediaList.whereType<Map>()) {
          final p = Map<String, dynamic>.from(raw);
          final id = (p['id'] ?? '').toString();
          if (id.isEmpty) continue;
          final author = _authorName(p);
          final caption = (p['caption'] ?? '').toString().trim();
          items.add(
            _ActivityItem(
              id: 'post:$id',
              kind: _ActivityKind.post,
              title: '$author shared a post',
              subtitle: caption.isEmpty ? null : caption,
              when: _parseDate(
                p['createdAt'] ?? p['created_at'] ?? p['uploadedAt'],
              ),
              imageUrl: _postImage(p),
              isRead: true,
              raw: p,
            ),
          );
        }
      }

      items.sort((a, b) {
        final aw = a.when ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bw = b.when ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bw.compareTo(aw);
      });

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      context.read<FamilyNoticesUnreadProvider>().refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onTap(_ActivityItem item) async {
    switch (item.kind) {
      case _ActivityKind.notification:
        final rawId = (item.raw?['id'] ?? '').toString();
        if (rawId.isNotEmpty && !item.isRead) {
          try {
            await context
                .read<FamilyApiService>()
                .markNotificationRead(rawId);
            if (!mounted) return;
            setState(() {
              _items = _items
                  .map(
                    (e) => e.id == item.id
                        ? _ActivityItem(
                            id: e.id,
                            kind: e.kind,
                            title: e.title,
                            subtitle: e.subtitle,
                            when: e.when,
                            imageUrl: e.imageUrl,
                            isRead: true,
                            raw: e.raw,
                          )
                        : e,
                  )
                  .toList();
            });
            context.read<FamilyNoticesUnreadProvider>().refresh();
          } catch (_) {}
        }
        break;
      case _ActivityKind.notice:
        if (!mounted) return;
        context.openShell('/family/messages');
        break;
      case _ActivityKind.post:
        if (!mounted) return;
        context.openShell('/family/media');
        break;
    }
  }

  IconData _iconFor(_ActivityKind kind, bool isRead) {
    switch (kind) {
      case _ActivityKind.notification:
        return isRead
            ? Icons.notifications_none_outlined
            : Icons.notifications_active_rounded;
      case _ActivityKind.notice:
        return Icons.campaign_rounded;
      case _ActivityKind.post:
        return Icons.photo_library_outlined;
    }
  }

  String _kindLabel(_ActivityKind kind) {
    switch (kind) {
      case _ActivityKind.notification:
        return 'Update';
      case _ActivityKind.notice:
        return 'Important';
      case _ActivityKind.post:
        return 'Post';
    }
  }

  String _whenLabel(DateTime? when) {
    if (when == null) return '';
    return DateFormat.MMMd().add_jm().format(when.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return FtBrandedPage(
      title: 'Activity',
      subtitle: 'Posts, notices & family updates',
      actions: [
        IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.openShell('/family/media');
            }
          },
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: Icon(Icons.refresh_rounded, color: AppTheme.ink),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          _error!,
                          style: AppTheme.body(color: Colors.red, size: 13),
                        ),
                      ],
                    )
                  : _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.45,
                              child: Center(
                                child: Text(
                                  'No activity yet',
                                  style: AppTheme.body(
                                    size: 14,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return Material(
                              color: item.isRead
                                  ? AppTheme.card
                                  : AppTheme.unreadFill,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _onTap(item),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.borderSoft,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.forest
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _iconFor(item.kind, item.isRead),
                                          color: AppTheme.forest,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.forest
                                                        .withValues(
                                                      alpha: 0.08,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      99,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _kindLabel(item.kind),
                                                    style: AppTheme.body(
                                                      size: 10,
                                                      weight: FontWeight.w700,
                                                      color: AppTheme.forest,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (item.when != null)
                                                  Text(
                                                    _whenLabel(item.when),
                                                    style: AppTheme.body(
                                                      size: 11,
                                                      color: AppTheme.muted,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item.title,
                                              style: AppTheme.body(
                                                size: 14,
                                                weight: item.isRead
                                                    ? FontWeight.w500
                                                    : FontWeight.w700,
                                              ),
                                            ),
                                            if ((item.subtitle ?? '')
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                item.subtitle!,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTheme.body(
                                                  size: 13,
                                                  color: AppTheme.mutedSoft,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (item.imageUrl != null) ...[
                                        const SizedBox(width: 10),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.network(
                                            item.imageUrl!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 56,
                                              height: 56,
                                              color: AppTheme.softFill,
                                              child: Icon(
                                                Icons.image_outlined,
                                                color: AppTheme.muted,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}
