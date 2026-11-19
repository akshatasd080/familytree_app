import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';

class FamilyMediaScreen extends StatefulWidget {
  const FamilyMediaScreen({super.key});

  @override
  State<FamilyMediaScreen> createState() => _FamilyMediaScreenState();
}

class _FamilyMediaScreenState extends State<FamilyMediaScreen> {
  List<Map<String, dynamic>> _media = const [];
  List<FamilyMember> _members = const [];
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
      final api = context.read<FamilyApiService>();
      final results = await Future.wait([
        api.listFamilyMedia(familyId),
        api.listFamilyMembers(familyId),
      ]);
      final data = results[0].data;
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

      final mdata = results[1].data;
      List mlist = const [];
      if (mdata is Map && mdata['members'] is List) {
        mlist = mdata['members'] as List;
      } else if (mdata is List) {
        mlist = mdata;
      }
      _members = mlist
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
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

  bool _likedByMe(Map<String, dynamic> item) =>
      item['likedByMe'] == true || item['liked'] == true;

  List _comments(Map<String, dynamic> item) {
    final c = item['comments'];
    return c is List ? c : const [];
  }

  static const _feelingTabs = <(String, String, List<(String, String)>)>[
    (
      'feelings',
      'Feelings',
      [
        ('😊', 'happy'),
        ('🥰', 'loved'),
        ('😎', 'cool'),
        ('🤩', 'excited'),
        ('😌', 'blessed'),
        ('😇', 'thankful'),
        ('💪', 'motivated'),
        ('😴', 'tired'),
        ('😢', 'sad'),
        ('😤', 'angry'),
        ('🤒', 'sick'),
        ('🤔', 'confused'),
      ],
    ),
    (
      'activities',
      'Activities',
      [
        ('🎉', 'celebrating'),
        ('✈️', 'traveling'),
        ('🍽️', 'eating'),
        ('☕', 'having coffee'),
        ('🎬', 'watching'),
        ('📚', 'reading'),
        ('🏃', 'exercising'),
        ('🎮', 'gaming'),
        ('🛒', 'shopping'),
        ('🎧', 'listening to music'),
        ('🧑‍🍳', 'cooking'),
        ('💤', 'relaxing'),
      ],
    ),
    (
      'family',
      'Family',
      [
        ('👨‍👩‍👧‍👦', 'with family'),
        ('❤️', 'grateful for family'),
        ('🏠', 'at home'),
        ('🎂', 'birthday vibes'),
        ('🪔', 'festival mood'),
        ('👶', 'with kids'),
        ('👴', 'with elders'),
        ('🤝', 'reunited'),
      ],
    ),
    (
      'weather',
      'Weather',
      [
        ('☀️', 'sunny'),
        ('🌧️', 'rainy'),
        ('❄️', 'cold'),
        ('🌤️', 'pleasant'),
        ('🌪️', 'stormy'),
        ('🌈', 'after the rain'),
      ],
    ),
  ];

  Future<void> _compose() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final caption = TextEditingController();
    String? path;
    (String, String)? feeling; // emoji, label
    var feelingTab = 0;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.canvas,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final canPost = path != null ||
              caption.text.trim().isNotEmpty ||
              feeling != null;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New post', style: AppTheme.display(size: 20)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (file != null) setLocal(() => path = file.path);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.forest.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.forest.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        path == null
                            ? 'Tap to choose photo (optional)'
                            : 'Photo selected',
                        style: AppTheme.body(
                          weight: FontWeight.w700,
                          color: AppTheme.forest,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: caption,
                    maxLines: 3,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Caption',
                      hintText: 'Say something, add a feeling, or a photo…',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (feeling != null)
                    Chip(
                      avatar: Text(feeling!.$1),
                      label: Text('feeling ${feeling!.$2}'),
                      onDeleted: () => setLocal(() => feeling = null),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showModalBottomSheet<(String, String)>(
                        context: ctx,
                        showDragHandle: true,
                        builder: (feelCtx) => StatefulBuilder(
                          builder: (feelCtx, setFeel) {
                            final tab = _feelingTabs[feelingTab];
                            return SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'How are you feeling?',
                                      style: AppTheme.display(size: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        for (var i = 0;
                                            i < _feelingTabs.length;
                                            i++)
                                          ChoiceChip(
                                            label: Text(_feelingTabs[i].$2),
                                            selected: feelingTab == i,
                                            onSelected: (_) =>
                                                setFeel(() => feelingTab = i),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final item in tab.$3)
                                          ActionChip(
                                            avatar: Text(item.$1),
                                            label: Text(item.$2),
                                            onPressed: () =>
                                                Navigator.pop(feelCtx, item),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                      if (picked != null) setLocal(() => feeling = picked);
                    },
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    label: const Text('Feeling'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          canPost ? () => Navigator.pop(ctx, true) : null,
                      child: const Text('Post'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    final text = caption.text.trim();
    final feelingPhrase =
        feeling == null ? '' : '${feeling!.$1} feeling ${feeling!.$2}';
    final finalCaption =
        [text, feelingPhrase].where((e) => e.isNotEmpty).join('\n');
    if (path == null && finalCaption.isEmpty) return;
    try {
      await context.read<FamilyApiService>().uploadFamilyMedia(
            familyId,
            filePath: path,
            caption: finalCaption.isEmpty ? null : finalCaption,
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
        var liked = _likedByMe(item);
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
                      )
                    else if ((item['caption'] ?? '').toString().isNotEmpty)
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              item['caption'].toString(),
                              textAlign: TextAlign.center,
                              style: AppTheme.body(size: 16),
                            ),
                          ),
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
                                      final res = await context
                                          .read<FamilyApiService>()
                                          .likeFamilyMedia(familyId, id);
                                      final data = res.data;
                                      setLocal(() {
                                        if (data is Map) {
                                          liked = data['liked'] == true;
                                          final count = data['likeCount'] ??
                                              data['likesCount'];
                                          if (count != null) {
                                            likes = count is int
                                                ? count
                                                : int.tryParse(
                                                      count.toString(),
                                                    ) ??
                                                    likes;
                                          } else {
                                            likes = liked
                                                ? likes + 1
                                                : (likes > 0 ? likes - 1 : 0);
                                          }
                                        }
                                        item['likedByMe'] = liked;
                                        item['likeCount'] = likes;
                                      });
                                    } catch (_) {}
                                  },
                                  icon: Icon(
                                    liked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
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

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    final id = (item['id'] ?? '').toString();
    if (familyId == null || id.isEmpty) return;
    try {
      final res =
          await context.read<FamilyApiService>().likeFamilyMedia(familyId, id);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        final liked = data['liked'] == true;
        item['likedByMe'] = liked;
        final count = data['likeCount'] ?? data['likesCount'];
        if (count != null) {
          item['likeCount'] =
              count is int ? count : int.tryParse('$count') ?? _likes(item);
        } else {
          item['likeCount'] =
              liked ? _likes(item) + 1 : (_likes(item) > 0 ? _likes(item) - 1 : 0);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _buildStoriesStrip() {
    final living = _members.where((m) => m.isAlive).take(16).toList();
    if (living.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        itemCount: living.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _StoryBubble(
              label: 'Post',
              isCreate: true,
              onTap: _compose,
            );
          }
          final m = living[i - 1];
          return _StoryBubble(
            label: m.name.split(' ').first,
            avatarUrl: mediaUrl(m.avatar),
            onTap: () => context.openShell('/family/tree'),
          );
        },
      ),
    );
  }

  Widget _buildFeed() {
    if (_media.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        children: [
          _buildStoriesStrip(),
          const SizedBox(height: 48),
          Icon(Icons.photo_library_outlined, size: 48, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(
            'No family posts yet',
            textAlign: TextAlign.center,
            style: AppTheme.display(size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Share a photo or feeling to start your family feed.',
            textAlign: TextAlign.center,
            style: AppTheme.body(color: AppTheme.muted),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _compose,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Create post'),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 100, top: 4),
      itemCount: _media.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildStoriesStrip();
        final item = _media[i - 1];
        final url = _imageUrl(item);
        final created =
            item['createdAt'] ?? item['created_at'] ?? item['uploadedAt'];
        final when = DateTime.tryParse('$created');
        final author = _author(item);
        final liked = _likedByMe(item);
        final caption = (item['caption'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            border: Border(
              top: BorderSide(color: AppTheme.borderSoft),
              bottom: BorderSide(color: AppTheme.borderSoft),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.forest,
                            AppTheme.emerald600,
                            const Color(0xFFD4AF68),
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: AppTheme.card,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor:
                              AppTheme.forest.withValues(alpha: 0.12),
                          child: Text(
                            author.isNotEmpty ? author[0].toUpperCase() : '?',
                            style: AppTheme.body(
                              weight: FontWeight.w800,
                              color: AppTheme.forest,
                              size: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            style: AppTheme.body(
                              weight: FontWeight.w800,
                              size: 14,
                            ),
                          ),
                          if (when != null)
                            Text(
                              DateFormat.MMMd().add_jm().format(when.toLocal()),
                              style: AppTheme.body(
                                size: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openPost(item),
                      icon: Icon(Icons.more_horiz, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              if (url != null)
                GestureDetector(
                  onDoubleTap: () => _toggleLike(item),
                  onTap: () => _openPost(item),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(
                        color: AppTheme.tabTrack,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.tabTrack,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined,
                            color: AppTheme.muted),
                      ),
                    ),
                  ),
                )
              else if (caption.isNotEmpty)
                GestureDetector(
                  onTap: () => _openPost(item),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.forest.withValues(alpha: 0.12),
                          AppTheme.cream,
                        ],
                      ),
                    ),
                    child: Text(
                      caption,
                      style: AppTheme.display(size: 18, height: 1.35),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _toggleLike(item),
                      icon: Icon(
                        liked ? Icons.favorite_rounded : Icons.favorite_border,
                        color: liked ? AppTheme.accentPink : AppTheme.ink,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openPost(item),
                      icon: Icon(
                        Icons.mode_comment_outlined,
                        color: AppTheme.ink,
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.openShell('/family/chat'),
                      icon: Icon(
                        Icons.send_outlined,
                        color: AppTheme.ink,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${_likes(item)} likes · ${_comments(item).length} comments',
                        style: AppTheme.body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppTheme.mutedSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (caption.isNotEmpty && url != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: RichText(
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: AppTheme.body(size: 13),
                      children: [
                        TextSpan(
                          text: '$author ',
                          style: AppTheme.body(
                            size: 13,
                            weight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: caption),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyId = context.watch<FamilySessionProvider>().familyId;
    return FtPage(
      title: 'Family Feed',
      actions: [
        IconButton(
          tooltip: 'Chat',
          onPressed: () => context.openShell('/family/chat'),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _compose,
        backgroundColor: AppTheme.forest,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : familyId == null
                  ? const Center(child: Text('No family'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _buildFeed(),
                    ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    required this.onTap,
    this.avatarUrl,
    this.isCreate = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? avatarUrl;
  final bool isCreate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isCreate
                    ? null
                    : LinearGradient(
                        colors: [
                          AppTheme.forest,
                          AppTheme.emerald600,
                          const Color(0xFFD4AF68),
                        ],
                      ),
                border: isCreate
                    ? Border.all(color: AppTheme.border, width: 1.5)
                    : null,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.card,
                  border: Border.all(color: AppTheme.card, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: isCreate
                    ? Icon(Icons.add, color: AppTheme.forest)
                    : avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              label.isNotEmpty ? label[0].toUpperCase() : '?',
                              style: AppTheme.body(
                                weight: FontWeight.w800,
                                color: AppTheme.forest,
                              ),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 11, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
