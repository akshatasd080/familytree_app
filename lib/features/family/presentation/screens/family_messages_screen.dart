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
  bool _isAdmin = false;
  String _viewerId = '';
  bool _loading = true;
  bool _composeOpen = false;
  String? _error;
  String? _markedKey;

  final _composeBody = TextEditingController();
  String? _composeImagePath;
  bool _composeSaving = false;
  String? _composeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _composeBody.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final api = context.read<FamilyApiService>();
      final session = context.read<FamilySessionProvider>();
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
        _isAdmin = false;
        _viewerId = '';
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
      final list =
          (data['notices'] is List) ? data['notices'] as List : const [];
      setState(() {
        _notices = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _canPost = data['canPost'] == true;
        _isAdmin = data['isAdmin'] == true;
        _viewerId = data['viewerId']?.toString() ?? '';
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
        _isAdmin = false;
        _viewerId = '';
        _loading = false;
      });
    }
  }

  bool _canDeleteNotice(Map<String, dynamic> notice) {
    if (_isAdmin) return true;
    final author = notice['author'];
    final authorId = author is Map ? author['id']?.toString() ?? '' : '';
    return authorId.isNotEmpty && authorId == _viewerId;
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

  void _openCompose() {
    if (_familyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No family selected.')),
      );
      return;
    }
    if (!_canPost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to post notices.'),
        ),
      );
      return;
    }
    setState(() {
      _composeOpen = true;
      _composeError = null;
      _composeSaving = false;
      _composeImagePath = null;
      _composeBody.clear();
    });
  }

  void _closeCompose() {
    setState(() {
      _composeOpen = false;
      _composeError = null;
      _composeSaving = false;
      _composeImagePath = null;
      _composeBody.clear();
    });
  }

  Future<void> _pickComposeImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (file == null) return;
    final lower = file.path.toLowerCase();
    final okType = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
    if (!okType) {
      setState(() => _composeError = 'Use PNG, JPG, WEBP, or GIF only.');
      return;
    }
    setState(() {
      _composeImagePath = file.path;
      _composeError = null;
    });
  }

  Future<void> _submitCompose() async {
    final text = _composeBody.text.trim();
    final familyId = _familyId;
    if (text.isEmpty) {
      setState(() => _composeError = 'Write a message first.');
      return;
    }
    if (familyId == null) return;
    setState(() {
      _composeSaving = true;
      _composeError = null;
    });
    try {
      final res = await context.read<FamilyApiService>().createFamilyNotice(
            familyId,
            body: text,
            imagePath: _composeImagePath,
          );
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final notice = data['notice'];
      if (!mounted) return;
      setState(() {
        _composeOpen = false;
        _composeSaving = false;
        _composeImagePath = null;
        _composeBody.clear();
        if (notice is Map) {
          _notices = [Map<String, dynamic>.from(notice), ..._notices];
        }
      });
      context.read<FamilyNoticesUnreadProvider>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Important message posted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _composeError = e.toString();
        _composeSaving = false;
      });
    }
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
        _notices =
            _notices.where((n) => n['id']?.toString() != noticeId).toList();
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Message removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _when(dynamic value) {
    if (value == null) return '';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return '';
    return DateFormat('d MMM yyyy · HH:mm').format(dt.toLocal());
  }

  Widget _buildComposeBody() {
    return ColoredBox(
      color: AppTheme.shellBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSoft),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _composeBody,
                  maxLines: 6,
                  minLines: 5,
                  maxLength: 2000,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share something with the family…',
                    hintStyle: TextStyle(color: AppTheme.muted),
                    filled: true,
                    fillColor: AppTheme.softFill,
                    counterStyle: TextStyle(color: AppTheme.muted),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF059669),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Photo (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _composeSaving ? null : _pickComposeImage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.ink,
                        backgroundColor: AppTheme.card,
                        side: BorderSide(color: AppTheme.border),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _composeImagePath == null ? 'Add photo' : 'Change photo',
                      ),
                    ),
                    if (_composeImagePath != null)
                      TextButton(
                        onPressed: _composeSaving
                            ? null
                            : () => setState(() => _composeImagePath = null),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Color(0xFFE11D48)),
                        ),
                      ),
                  ],
                ),
                if (_composeImagePath != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_composeImagePath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (_composeError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _composeError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _composeSaving ? null : _closeCompose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.ink,
                          side: BorderSide(color: AppTheme.border),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _composeSaving ? null : _submitCompose,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: _composeSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_composeSaving ? 'Posting…' : 'Post'),
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

  Widget _buildListBody(FamilySummary? selectedFamily) {
    return RefreshIndicator(
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
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.emerald600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Family notices with text or photos. Any family member can post for everyone to see.',
                  style: AppTheme.body(size: 13, color: AppTheme.muted),
                ),
              ),
            ],
          ),
          if (_canPost) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _openCompose,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Post message'),
              ),
            ),
          ],
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderSoft),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No important messages yet',
                    style: AppTheme.body(weight: FontWeight.w800, size: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _canPost
                        ? 'Post a notice with text or photo for the family.'
                        : 'When a family member posts, it will show up here.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(size: 13, color: AppTheme.muted),
                  ),
                  if (_canPost) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openCompose,
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text(
                        'Post first message',
                        style: TextStyle(color: Colors.black),
                      ),
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
                familyName: selectedFamily?.name ?? '',
                canDelete: _canDeleteNotice(notice),
                onDelete: () => _remove(notice['id']?.toString() ?? ''),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFamily = _families.cast<FamilySummary?>().firstWhere(
          (f) => f?.id == _familyId,
          orElse: () => null,
        );

    if (_composeOpen) {
      return FtBrandedPage(
        title: 'Post family message',
        subtitle: 'Share with your family',
        scenicBackground: false,
        backgroundColor: AppTheme.shellBg,
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: _composeSaving ? null : _closeCompose,
            icon: Icon(Icons.close, color: AppTheme.ink),
          ),
        ],
        body: _buildComposeBody(),
      );
    }

    return FtBrandedPage(
      title: 'Messages',
      subtitle: 'Family notices with text or photos',
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
      body: _buildListBody(selectedFamily),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.when,
    required this.familyName,
    required this.canDelete,
    required this.onDelete,
  });

  final Map<String, dynamic> notice;
  final String when;
  final String familyName;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isRead = notice['isRead'] == true;
    final author = notice['author'];
    final authorName = author is Map
        ? (author['name']?.toString() ?? 'Family member')
        : 'Family member';
    final body = notice['body']?.toString() ?? '';
    final location = notice['location']?.toString() ?? '';
    final imagePath = notice['imagePath']?.toString();
    final image = mediaUrl(imagePath);
    final meta = [
      if (when.isNotEmpty) when,
      if (familyName.trim().isNotEmpty) familyName.trim(),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? AppTheme.borderSoft : const Color(0xFFA7F3D0),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
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
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: AppTheme.body(size: 11, color: AppTheme.muted),
                        ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderSoft),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: AppTheme.body(
                    size: 14,
                    color: AppTheme.ink,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.softFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppTheme.emerald600,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location,
                            style: AppTheme.body(
                              size: 12,
                              color: AppTheme.mutedSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
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
        ],
      ),
    );
  }
}
