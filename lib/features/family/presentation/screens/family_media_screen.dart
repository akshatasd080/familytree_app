import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';
import '../providers/family_providers.dart';

class FamilyMediaScreen extends StatefulWidget {
  const FamilyMediaScreen({super.key});

  @override
  State<FamilyMediaScreen> createState() => _FamilyMediaScreenState();
}

class _FamilyMediaScreenState extends State<FamilyMediaScreen> {
  List<Map<String, dynamic>> _media = const [];
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
      final res =
          await context.read<FamilyApiService>().listFamilyMedia(familyId);
      final data = res.data;
      List list = const [];
      if (data is Map && data['media'] is List) {
        list = data['media'] as List;
      } else if (data is List) {
        list = data;
      }
      _media = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _imageUrl(Map<String, dynamic> item) => mediaUrl(
        (item['url'] ??
                item['image'] ??
                item['path'] ??
                item['file_path'] ??
                item['filePath'])
            ?.toString(),
      );

  String _author(Map<String, dynamic> item) {
    final user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'] as Map)
        : null;
    return (item['authorName'] ??
            item['uploadedByName'] ??
            user?['name'] ??
            item['name'] ??
            'Family')
        .toString();
  }

  int _likes(Map<String, dynamic> item) {
    final v = item['likesCount'] ??
        item['likeCount'] ??
        item['likes'] ??
        (item['likedBy'] is List ? (item['likedBy'] as List).length : 0);
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  List _comments(Map<String, dynamic> item) {
    final c = item['comments'];
    return c is List ? c : const [];
  }

  Future<void> _compose() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final caption = TextEditingController();
    String? path;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New post', style: AppTheme.display(size: 20)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final file = await ImagePicker()
                      .pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (file != null) setLocal(() => path = file.path);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFBCFE8)),
                  ),
                  child: Text(
                    path == null ? 'Tap to choose photo' : 'Photo selected',
                    style: AppTheme.body(
                      weight: FontWeight.w700,
                      color: AppTheme.accentPink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: caption,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption',
                  hintText: 'Say something about this memory…',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentPink,
                  ),
                  onPressed: path == null ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || path == null || !mounted) return;
    try {
      await context.read<FamilyApiService>().uploadFamilyMedia(
            familyId,
            filePath: path!,
            caption: caption.text.trim(),
          );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openPost(Map<String, dynamic> item) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final id = (item['id'] ?? '').toString();
    final commentCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.card,
      showDragHandle: true,
      builder: (ctx) {
        var likes = _likes(item);
        var comments = [..._comments(item)];
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final url = _imageUrl(item);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.85,
                child: Column(
                  children: [
                    if (url != null)
                      Expanded(
                        flex: 5,
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _author(item),
                              style: AppTheme.body(weight: FontWeight.w800),
                            ),
                            if ((item['caption'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(item['caption'].toString()),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    try {
                                      await context
                                          .read<FamilyApiService>()
                                          .likeFamilyMedia(familyId, id);
                                      setLocal(() => likes += 1);
                                    } catch (_) {}
                                  },
                                  icon: Icon(
                                    Icons.favorite,
                                    color: AppTheme.accentPink,
                                  ),
                                ),
                                Text('$likes likes'),
                                const Spacer(),
                                IconButton(
                                  onPressed: () async {
                                    try {
                                      await context
                                          .read<FamilyApiService>()
                                          .deleteFamilyMedia(familyId, id);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _load();
                                    } catch (e) {
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('$e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Comments',
                              style: AppTheme.body(weight: FontWeight.w700),
                            ),
                            Expanded(
                              child: ListView(
                                children: [
                                  for (final c in comments)
                                    if (c is Map)
                                      ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          (c['body'] ?? c['text'] ?? '')
                                              .toString(),
                                        ),
                                        subtitle: Text(
                                          (c['authorName'] ??
                                                  c['user']?['name'] ??
                                                  '')
                                              .toString(),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: commentCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'Write a comment…',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final body = commentCtrl.text.trim();
                                    if (body.isEmpty) return;
                                    try {
                                      await context
                                          .read<FamilyApiService>()
                                          .commentFamilyMedia(
                                            familyId,
                                            id,
                                            body,
                                          );
                                      setLocal(() {
                                        comments = [
                                          ...comments,
                                          {'body': body, 'authorName': 'You'},
                                        ];
                                        commentCtrl.clear();
                                      });
                                    } catch (e) {
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('$e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.send,
                                    color: Color(0xFFFF5C8A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FtPage(
      title: 'Media',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: AppTheme.accentPink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Post'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _media.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No photos yet')),
                          ],
                        )
                      : ListView.builder(
                          padding: context.pagePadding.copyWith(bottom: 88),
                          itemCount: _media.length,
                          itemBuilder: (_, i) {
                            final item = _media[i];
                            final url = _imageUrl(item);
                            final created = item['createdAt'] ??
                                item['created_at'] ??
                                item['uploadedAt'];
                            final when = DateTime.tryParse('$created');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: () => _openPost(item),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFFCE7F3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            12,
                                            12,
                                            8,
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: AppTheme
                                                    .accentPink
                                                    .withValues(alpha: 0.15),
                                                child: Text(
                                                  _author(item).isNotEmpty
                                                      ? _author(item)[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFFF5C8A),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _author(item),
                                                      style: AppTheme.body(
                                                        weight: FontWeight.w800,
                                                      ),
                                                    ),
                                                    if (when != null)
                                                      Text(
                                                        DateFormat.yMMMd()
                                                            .add_jm()
                                                            .format(
                                                              when.toLocal(),
                                                            ),
                                                        style: AppTheme.body(
                                                          size: 11,
                                                          color: AppTheme.muted,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AspectRatio(
                                          aspectRatio: 4 / 3,
                                          child: url == null
                                              ? Container(
                                                  color: Colors.black12,
                                                  child: const Icon(Icons.image),
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: url,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            10,
                                            12,
                                            12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.favorite,
                                                    size: 16,
                                                    color: Color(0xFFFF5C8A),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text('${_likes(item)}'),
                                                  const SizedBox(width: 12),
                                                  const Icon(
                                                    Icons.chat_bubble_outline,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${_comments(item).length}',
                                                  ),
                                                ],
                                              ),
                                              if ((item['caption'] ?? '')
                                                  .toString()
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  item['caption'].toString(),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
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
