import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_branded_page.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';
import '../widgets/state_city_select.dart';

class FamilyMessagesScreen extends StatefulWidget {
  const FamilyMessagesScreen({super.key});

  @override
  State<FamilyMessagesScreen> createState() => _FamilyMessagesScreenState();
}

class _FamilyMessagesScreenState extends State<FamilyMessagesScreen> {
  List<FamilySummary> _families = const [];
  String? _familyId;
  List<Map<String, dynamic>> _notices = const [];
  bool _canPost = false;
  bool _loading = true;
  String? _error;
  String? _markedKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final api = context.read<FamilyApiService>();
      final session = context.read<FamilySessionProvider>();
      // Web parity: load families from /families/mine, then notices.
      List<FamilySummary> families = session.families;
      try {
        final res = await api.listMyFamilies();
        final data = res.data;
        List list = const [];
        if (data is Map && data['families'] is List) {
          list = data['families'] as List;
        } else if (data is List) {
          list = data;
        }
        families = list
            .whereType<Map>()
            .map((e) => FamilySummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (families.isNotEmpty) {
          // Keep session in sync so other tabs use the same family.
          if (session.families.isEmpty) await session.loadMine();
        }
      } catch (_) {
        if (families.isEmpty) {
          await session.loadMine();
          if (!mounted) return;
          families = session.families;
        }
      }
      if (!mounted) return;
      final selected = _familyId ??
          session.familyId ??
          (families.isNotEmpty ? families.first.id : null);
      setState(() {
        _families = families;
        _familyId = selected;
      });
      await _loadNotices();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _notices = const [];
      });
    }
  }

  Future<void> _loadNotices() async {
    final id = _familyId;
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notices = const [];
        _canPost = false;
        _error = 'No family selected. Open Dashboard and pull to refresh.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<FamilyApiService>().listFamilyNotices(id);
      if (!mounted) return;
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final list = (data['notices'] is List) ? data['notices'] as List : const [];
      setState(() {
        _notices = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _canPost = data['canPost'] == true;
        _loading = false;
        _error = null;
      });
      _markUnreadRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _notices = const [];
        _canPost = false;
        _loading = false;
      });
    }
  }

  Future<void> _markUnreadRead() async {
    final id = _familyId;
    if (id == null || _notices.isEmpty) return;
    final unreadIds = _notices
        .where((n) => n['isRead'] != true)
        .map((n) => n['id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    if (unreadIds.isEmpty) return;
    final key = '$id:${unreadIds.join(',')}';
    if (_markedKey == key) return;
    _markedKey = key;
    try {
      await context
          .read<FamilyApiService>()
          .markFamilyNoticesRead(id, noticeIds: unreadIds);
      if (!mounted) return;
      setState(() {
        _notices = _notices
            .map((n) => {...n, 'isRead': true})
            .toList(growable: false);
      });
      context.read<FamilyNoticesUnreadProvider>().refresh();
    } catch (_) {
      _markedKey = null;
    }
  }

  Future<void> _openCompose() async {
    final id = _familyId;
    if (id == null || !_canPost) return;
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.canvas,
      builder: (ctx) => const _ComposeNoticeSheet(),
    );
    if (created == null || !mounted) return;
    setState(() {
      _notices = [created, ..._notices];
    });
    context.read<FamilyNoticesUnreadProvider>().refresh();
  }

  Future<void> _remove(String noticeId) async {
    final id = _familyId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove message?'),
        content: const Text('This important message will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = context.read<FamilyApiService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.deleteFamilyNotice(id, noticeId);
      if (!mounted) return;
      setState(() {
        _notices = _notices.where((n) => n['id']?.toString() != noticeId).toList();
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Message removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _when(dynamic value) {
    if (value == null) return '';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return '';
    return DateFormat('d MMM yyyy · HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return FtBrandedPage(
      title: 'Notices',
      subtitle: 'Important family updates',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _bootstrap,
          icon: Icon(Icons.refresh_rounded, color: AppTheme.ink),
        ),
        if (_canPost)
          IconButton(
            tooltip: 'Post message',
            onPressed: _openCompose,
            icon: Icon(Icons.add_circle_outline, color: AppTheme.forest),
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.forum, color: AppTheme.emerald600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Important family notices from admins. Everyone can read; only admins can post.',
                    style: AppTheme.body(size: 13, color: AppTheme.muted),
                  ),
                ),
              ],
            ),
            if (_families.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _families)
                    ChoiceChip(
                      label: Text(
                        f.name,
                        style: const TextStyle(color: Colors.black),
                      ),
                      labelStyle: const TextStyle(color: Colors.black),
                      selected: f.id == _familyId,
                      onSelected: (_) async {
                        setState(() {
                          _familyId = f.id;
                          _markedKey = null;
                        });
                        context.read<FamilySessionProvider>().selectFamily(f);
                        await _loadNotices();
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTheme.body(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _bootstrap,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_notices.isEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.borderSoft,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.forum_outlined, size: 48, color: AppTheme.muted),
                    const SizedBox(height: 12),
                    Text(
                      'No important messages yet',
                      style: AppTheme.body(weight: FontWeight.w800, size: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _canPost
                          ? 'Post a notice with text or photo for the family.'
                          : 'When a family admin posts, it will show up here.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(size: 13, color: AppTheme.muted),
                    ),
                    if (_canPost) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _openCompose,
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text('Post first message'),
                      ),
                    ],
                  ],
                ),
              )
            else
              for (final notice in _notices)
                _NoticeCard(
                  notice: notice,
                  when: _when(notice['createdAt']),
                  canDelete: _canPost,
                  onDelete: () => _remove(notice['id']?.toString() ?? ''),
                ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.when,
    required this.canDelete,
    required this.onDelete,
  });

  final Map<String, dynamic> notice;
  final String when;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isRead = notice['isRead'] == true;
    final author = notice['author'];
    final authorName = author is Map
        ? (author['name']?.toString() ?? 'Family admin')
        : 'Family admin';
    final body = notice['body']?.toString() ?? '';
    final location = notice['location']?.toString() ?? '';
    final imagePath = notice['imagePath']?.toString();
    final image = mediaUrl(imagePath);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? AppTheme.borderSoft : AppTheme.emerald100,
          width: isRead ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            authorName,
                            style: AppTheme.body(
                              size: 14,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'New',
                              style: AppTheme.body(
                                size: 10,
                                weight: FontWeight.w700,
                                color: AppTheme.emerald600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (when.isNotEmpty)
                      Text(
                        when,
                        style: AppTheme.body(size: 11, color: AppTheme.muted),
                      ),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: AppTheme.body(size: 14)),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: AppTheme.emerald600),
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
            const SizedBox(height: 10),
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
    );
  }
}

class _ComposeNoticeSheet extends StatefulWidget {
  const _ComposeNoticeSheet();

  @override
  State<_ComposeNoticeSheet> createState() => _ComposeNoticeSheetState();
}

class _ComposeNoticeSheetState extends State<_ComposeNoticeSheet> {
  final _body = TextEditingController();
  String _location = '';
  String? _imagePath;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _imagePath = file.path);
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write a message first.');
      return;
    }
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await context.read<FamilyApiService>().createFamilyNotice(
            familyId,
            body: text,
            location: _location.trim().isEmpty ? null : _location.trim(),
            imagePath: _imagePath,
          );
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final notice = data['notice'];
      if (!mounted) return;
      if (notice is Map) {
        Navigator.pop(context, Map<String, dynamic>.from(notice));
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Post important message', style: AppTheme.display(size: 20)),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            StateCitySelect(
              value: _location,
              onChanged: (v) => setState(() => _location = v),
              showHint: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined, color: Colors.black),
                  label: Text(
                    _imagePath == null ? 'Add photo' : 'Change photo',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                if (_imagePath != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _imagePath = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            if (_imagePath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppTheme.body(color: Colors.red, size: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Post message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
