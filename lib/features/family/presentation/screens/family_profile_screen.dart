import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_branded_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/family_api_service.dart';
import '../../domain/profile_privacy.dart';
import '../providers/family_providers.dart';
import '../widgets/phone_change_otp_dialog.dart';
import '../widgets/state_city_select.dart';

const _bloodGroups = [
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
  'Unknown',
];

class FamilyProfileScreen extends StatefulWidget {
  const FamilyProfileScreen({super.key});

  @override
  State<FamilyProfileScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _about = TextEditingController();
  String? _dob;
  String? _marriage;
  String _blood = 'Unknown';
  String _treeCardShow = 'education';
  String? _avatar;
  Map<String, String> _privacy = normalizePrivacy(const {});
  final List<_PairFields> _educations = [];
  final List<_PairFields> _jobs = [];
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _postsLoading = false;
  bool _posting = false;
  String? _error;
  String _savedPhone = '';
  List<Map<String, dynamic>> _posts = const [];
  final Map<String, TextEditingController> _commentCtrls = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _about.dispose();
    for (final c in _commentCtrls.values) {
      c.dispose();
    }
    for (final e in _educations) {
      e.dispose();
    }
    for (final j in _jobs) {
      j.dispose();
    }
    super.dispose();
  }

  TextEditingController _commentCtrlFor(String postId) =>
      _commentCtrls.putIfAbsent(postId, TextEditingController.new);

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String? _postImageUrl(Map<String, dynamic> item) => mediaUrl(
        (item['url'] ??
                item['image'] ??
                item['path'] ??
                item['file_path'] ??
                item['filePath'])
            ?.toString(),
      );

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

  List<Map<String, dynamic>> _commentsOf(Map<String, dynamic> item) {
    final c = item['comments'];
    if (c is! List) return const [];
    return c
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _commentAuthor(Map<String, dynamic> c) {
    final author = _asMap(c['author']);
    final user = _asMap(c['user']);
    final name = (c['authorName'] ??
            c['userName'] ??
            c['name'] ??
            author?['name'] ??
            user?['name'] ??
            '')
        .toString()
        .trim();
    return name.isEmpty ? 'Family member' : name;
  }

  String _commentBody(Map<String, dynamic> c) =>
      (c['body'] ?? c['text'] ?? c['comment'] ?? '').toString().trim();

  String _likesLabel(Map<String, dynamic> item) {
    final n = _likes(item);
    final mine = _likedByMe(item);
    if (n <= 0) return 'No likes yet';
    if (mine && n == 1) return 'Liked by you';
    if (mine) return 'Liked by you and ${n - 1} other${n - 1 == 1 ? '' : 's'}';
    return '$n like${n == 1 ? '' : 's'}';
  }

  Future<void> _composePost() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No family selected')),
      );
      return;
    }
    final caption = TextEditingController();
    String? path;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.canvas,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final canPost =
              path != null || caption.text.trim().isNotEmpty;
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
                      height: 140,
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
                            ? 'Tap to choose photo'
                            : 'Photo selected ✓',
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
                      hintText: 'Write something about this moment…',
                    ),
                  ),
                  const SizedBox(height: 12),
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
    final text = caption.text.trim();
    caption.dispose();
    if (ok != true || !mounted) return;
    if (path == null && text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await context.read<FamilyApiService>().uploadFamilyMedia(
            familyId,
            filePath: path,
            caption: text.isEmpty ? null : text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post shared')),
      );
      await _loadPosts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
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

  Future<void> _sendComment(Map<String, dynamic> item) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    final id = (item['id'] ?? '').toString();
    if (familyId == null || id.isEmpty) return;
    final ctrl = _commentCtrlFor(id);
    final body = ctrl.text.trim();
    if (body.isEmpty) return;
    try {
      final res = await context
          .read<FamilyApiService>()
          .commentFamilyMedia(familyId, id, body);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final created = _asMap(data['comment']) ??
          <String, dynamic>{
            'body': body,
            'author': {'name': 'You'},
          };
      if (!mounted) return;
      setState(() {
        final list = List<Map<String, dynamic>>.from(_commentsOf(item))
          ..add(created);
        item['comments'] = list;
        ctrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String? _dateOnly(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null) return s.length >= 10 ? s.substring(0, 10) : s;
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  Future<void> _pickDate({required bool marriage}) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(marriage ? (_marriage ?? '') : (_dob ?? '')) ??
        DateTime(now.year - 25);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    final v = DateFormat('yyyy-MM-dd').format(picked);
    setState(() {
      if (marriage) {
        _marriage = v;
      } else {
        _dob = v;
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<FamilyApiService>().getMyFamilyProfile();
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final profile = data['profile'] is Map
          ? Map<String, dynamic>.from(data['profile'] as Map)
          : data;
      _name.text = (profile['name'] ?? data['name'] ?? '').toString();
      _email.text = (profile['email'] ?? data['email'] ?? '').toString();
      if (_email.text.endsWith('@phone.familytree.local')) _email.clear();
      _phone.text = (profile['phone'] ?? data['phone'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\D'), '')
          .replaceFirst(RegExp(r'^91'), '');
      if (_phone.text.length > 10) {
        _phone.text = _phone.text.substring(_phone.text.length - 10);
      }
      _savedPhone = _phone.text;
      final loc = (profile['location'] ?? '').toString();
      if (loc.isNotEmpty) {
        _location.text = loc;
      } else {
        final city = (profile['city'] ?? '').toString();
        final state = (profile['state'] ?? '').toString();
        _location.text = [city, state].where((e) => e.isNotEmpty).join(', ');
      }
      _about.text = (profile['about'] ?? '').toString();
      _dob = _dateOnly(profile['dateOfBirth'] ?? profile['date_of_birth']);
      _marriage =
          _dateOnly(profile['dateOfMarriage'] ?? profile['date_of_marriage']);
      final bg = (profile['bloodGroup'] ?? profile['blood_group'] ?? 'Unknown')
          .toString();
      _blood = _bloodGroups.contains(bg) ? bg : 'Unknown';
      _treeCardShow =
          (profile['treeCardShow'] ?? profile['tree_card_show'] ?? 'education')
                      .toString()
                      .toLowerCase() ==
                  'job'
              ? 'job'
              : 'education';
      _avatar = (profile['avatar'] ?? data['avatar'])?.toString();
      _privacy = normalizePrivacy(profile['privacy'] ?? data['privacy']);

      for (final e in _educations) {
        e.dispose();
      }
      _educations.clear();
      final edu = profile['educations'];
      if (edu is List) {
        for (final item in edu.whereType<Map>()) {
          _educations.add(
            _PairFields(
              item['course']?.toString() ?? '',
              item['school']?.toString() ?? '',
            ),
          );
        }
      }
      for (final j in _jobs) {
        j.dispose();
      }
      _jobs.clear();
      final jobs = profile['jobs'];
      if (jobs is List) {
        for (final item in jobs.whereType<Map>()) {
          _jobs.add(
            _PairFields(
              item['title']?.toString() ?? '',
              item['place']?.toString() ?? '',
            ),
          );
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _loadPosts();
      }
    }
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    final familyId = context.read<FamilySessionProvider>().familyId;
    final userId = context.read<AuthProvider>().user?.id;
    if (familyId == null || userId == null || userId.isEmpty) {
      if (mounted) setState(() => _posts = const []);
      return;
    }
    setState(() => _postsLoading = true);
    try {
      final res = await context.read<FamilyApiService>().listFamilyMedia(
            familyId,
            params: {'authorId': userId},
          );
      final data = res.data;
      List list = const [];
      if (data is Map && data['media'] is List) {
        list = data['media'] as List;
      } else if (data is List) {
        list = data;
      }
      final posts = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) {
            final author = (e['userId'] ??
                    e['user_id'] ??
                    e['authorId'] ??
                    e['uploadedBy'] ??
                    '')
                .toString();
            return author.isEmpty || author == userId;
          })
          .toList();
      if (!mounted) return;
      setState(() => _posts = posts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts = const []);
    } finally {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<void> _persistProfile(String phone) async {
    final name = _name.text.trim();
    await context.read<FamilyApiService>().updateMyFamilyProfile({
      'name': name,
      if (_email.text.trim().isNotEmpty)
        'email': _email.text.trim().toLowerCase(),
      'phone': phone,
      'location': _location.text.trim(),
      if (_dob != null) 'dateOfBirth': _dob,
      if (_marriage != null) 'dateOfMarriage': _marriage,
      'bloodGroup': _blood,
      'about': _about.text.trim(),
      'treeCardShow': _treeCardShow,
      'educations': [
        for (final e in _educations)
          if (e.a.text.trim().isNotEmpty || e.b.text.trim().isNotEmpty)
            {'course': e.a.text.trim(), 'school': e.b.text.trim()},
      ],
      'jobs': [
        for (final j in _jobs)
          if (j.a.text.trim().isNotEmpty || j.b.text.trim().isNotEmpty)
            {'title': j.a.text.trim(), 'place': j.b.text.trim()},
      ],
      'privacy': _privacy,
    });
    _savedPhone = phone;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (name.length < 2) {
      setState(() => _error = 'Enter a valid name.');
      return;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }

    // Login mobile changes only after OTP verify (matches web + backend).
    if (_savedPhone.isNotEmpty && phone != _savedPhone) {
      final api = context.read<FamilyApiService>();
      final verified = await showPhoneChangeOtpDialog(
        context: context,
        phone: phone,
        description:
            'OTP will be sent to +91 $phone. After verify, use this number to login.',
        onRequestOtp: (p) async {
          await api.requestMyPhoneChangeOtp(p);
        },
        onVerifyOtp: (p, otp) async {
          await api.verifyMyPhoneChangeOtp(p, otp);
        },
      );
      if (!mounted) return;
      if (!verified) {
        setState(() => _phone.text = _savedPhone);
        return;
      }
      setState(() {
        _phone.text = phone;
        _saving = true;
        _error = null;
      });
      try {
        await _persistProfile(phone);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mobile updated and profile saved')),
        );
      } catch (e) {
        setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _persistProfile(phone);
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    try {
      await context.read<FamilyApiService>().uploadMyFamilyAvatar(file.path);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FtBrandedPage(
      title: 'Profile',
      subtitle: _editing
          ? 'Edit your details'
          : 'Posts, family presence · like Instagram',
      actions: [
        if (_editing) ...[
          TextButton(
            onPressed: () => setState(() => _editing = false),
            child: Text(
              'Back',
              style: AppTheme.body(
                weight: FontWeight.w700,
                color: AppTheme.muted,
              ),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              'Save',
              style: AppTheme.body(
                weight: FontWeight.w800,
                color: AppTheme.forest,
              ),
            ),
          ),
        ],
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveBody(
              child: _editing ? _buildEditForm() : _buildSocialProfile(),
            ),
    );
  }

  Widget _buildSocialProfile() {
    final url = mediaUrl(_avatar);
    final name = _name.text.trim().isEmpty ? 'Your profile' : _name.text.trim();
    final about = _about.text.trim();
    final location = _location.text.trim();

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.forest,
                          AppTheme.forest.withValues(alpha: 0.45),
                          const Color(0xFFFBBF24),
                        ],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: AppTheme.card,
                      child: CircleAvatar(
                        radius: 39,
                        backgroundColor:
                            AppTheme.forest.withValues(alpha: 0.12),
                        backgroundImage:
                            url != null ? NetworkImage(url) : null,
                        child: url == null
                            ? const Icon(Icons.person, size: 36)
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Material(
                      color: AppTheme.forest,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickAvatar,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.photo_camera,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Row(
                  children: [
                    _StatCell(value: '${_posts.length}', label: 'Posts'),
                    _StatCell(
                      value: location.isEmpty ? '—' : '1',
                      label: 'Location',
                    ),
                    _StatCell(
                      value: _blood == 'Unknown' ? '—' : _blood,
                      label: 'Blood',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(name, style: AppTheme.display(size: 18)),
        if (about.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(about, style: AppTheme.body(size: 13)),
        ],
        if (location.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            location,
            style: AppTheme.body(size: 12, color: AppTheme.muted),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.forest,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit details'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => context.go('/family/chat'),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Message'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _posting ? null : _composePost,
          icon: _posting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(_posting ? 'Posting…' : 'Add a post'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Icon(Icons.grid_on_rounded, size: 18, color: AppTheme.ink),
            const SizedBox(width: 8),
            Text(
              'Posts',
              style: AppTheme.body(weight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_postsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_posts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.softFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSoft),
            ),
            child: Column(
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 36, color: AppTheme.muted),
                const SizedBox(height: 10),
                Text(
                  'No posts yet',
                  style: AppTheme.body(weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap “Add a post” above to share a photo from here.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(size: 12, color: AppTheme.muted),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemBuilder: (_, i) {
              final item = _posts[i];
              final src = _postImageUrl(item);
              final caption = (item['caption'] ?? '').toString().trim();
              final comments = _commentsOf(item).length;
              final likes = _likes(item);
              return InkWell(
                onTap: () => _openPostDetail(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (src != null)
                      CachedNetworkImage(
                        imageUrl: src,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppTheme.softFill),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.softFill,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      )
                    else
                      Container(
                        color: AppTheme.forest.withValues(alpha: 0.1),
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.center,
                        child: Text(
                          caption.isEmpty ? 'Post' : caption,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTheme.body(
                            size: 11,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (likes > 0 || comments > 0)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (likes > 0) ...[
                                const Icon(Icons.favorite,
                                    size: 10, color: Colors.white),
                                const SizedBox(width: 2),
                                Text(
                                  '$likes',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (likes > 0 && comments > 0)
                                const SizedBox(width: 6),
                              if (comments > 0) ...[
                                const Icon(Icons.mode_comment,
                                    size: 10, color: Colors.white),
                                const SizedBox(width: 2),
                                Text(
                                  '$comments',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _openPostDetail(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    final ctrl = _commentCtrlFor(id.isEmpty ? 'post' : id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.card,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final image = _postImageUrl(item);
            final caption = (item['caption'] ?? '').toString().trim();
            final comments = _commentsOf(item);
            final liked = _likedByMe(item);
            final name =
                _name.text.trim().isEmpty ? 'You' : _name.text.trim();

            Future<void> like() async {
              await _toggleLike(item);
              setLocal(() {});
            }

            Future<void> comment() async {
              await _sendComment(item);
              setLocal(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.92,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppTheme.forest.withValues(alpha: 0.12),
                            backgroundImage: mediaUrl(_avatar) != null
                                ? NetworkImage(mediaUrl(_avatar)!)
                                : null,
                            child: mediaUrl(_avatar) == null
                                ? Text(
                                    name[0].toUpperCase(),
                                    style: AppTheme.body(
                                      weight: FontWeight.w800,
                                      color: AppTheme.forest,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: AppTheme.body(weight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (image != null)
                      Expanded(
                        flex: 5,
                        child: CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      )
                    else if (caption.isNotEmpty)
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              caption,
                              textAlign: TextAlign.center,
                              style: AppTheme.display(size: 20),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: like,
                                  icon: Icon(
                                    liked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border,
                                    color: liked
                                        ? AppTheme.accentPink
                                        : AppTheme.ink,
                                  ),
                                ),
                                Text(
                                  _likesLabel(item),
                                  style: AppTheme.body(
                                    size: 13,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (caption.isNotEmpty && image != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: RichText(
                                  text: TextSpan(
                                    style: AppTheme.body(size: 13),
                                    children: [
                                      TextSpan(
                                        text: '$name ',
                                        style: AppTheme.body(
                                          size: 13,
                                          weight: FontWeight.w800,
                                        ),
                                      ),
                                      TextSpan(text: caption),
                                    ],
                                  ),
                                ),
                              ),
                            Text(
                              'Comments (${comments.length})',
                              style:
                                  AppTheme.body(weight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: comments.isEmpty
                                  ? Text(
                                      'No comments yet.',
                                      style: AppTheme.body(
                                        size: 13,
                                        color: AppTheme.muted,
                                      ),
                                    )
                                  : ListView(
                                      children: [
                                        for (final c in comments)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: RichText(
                                              text: TextSpan(
                                                style: AppTheme.body(size: 13),
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        '${_commentAuthor(c)} ',
                                                    style: AppTheme.body(
                                                      size: 13,
                                                      weight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: _commentBody(c),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: ctrl,
                                    decoration: const InputDecoration(
                                      hintText: 'Write a comment…',
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => comment(),
                                  ),
                                ),
                                IconButton(
                                  onPressed: comment,
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
    if (mounted) setState(() {});
  }

  Widget _buildEditForm() {
    final url = mediaUrl(_avatar);
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [AppTheme.unreadFill, AppTheme.softFill],
            ),
            border: Border.all(color: AppTheme.borderSoft),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.forest.withValues(alpha: 0.12),
                    backgroundImage: url != null ? NetworkImage(url) : null,
                    child: url == null
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppTheme.forest,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickAvatar,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.photo_camera,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.text.isEmpty ? 'Your profile' : _name.text,
                      style: AppTheme.display(size: 20),
                    ),
                    Text(
                      'Keep your details updated for the family tree.',
                      style: AppTheme.body(
                        size: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  _PrivacyFieldHeader(
                    label: 'Phone',
                    value: _privacy['phone'] ?? 'private',
                    onChanged: (v) => setState(
                      () => _privacy = {..._privacy, 'phone': v},
                    ),
                  ),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      counterText: '${_phone.text.length}/10',
                      helperText:
                          'Changing number needs OTP on the new mobile',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  StateCitySelect(
                    value: _location.text,
                    onChanged: (v) => setState(() => _location.text = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PrivacyFieldHeader(
                              label: 'Date of birth',
                              value: _privacy['dateOfBirth'] ?? 'private',
                              onChanged: (v) => setState(
                                () => _privacy = {
                                  ..._privacy,
                                  'dateOfBirth': v,
                                },
                              ),
                            ),
                            _DateField(
                              label: 'Date of birth',
                              value: _dob,
                              onTap: () => _pickDate(marriage: false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateField(
                          label: 'Marriage date',
                          value: _marriage,
                          onTap: () => _pickDate(marriage: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PrivacyFieldHeader(
                    label: 'Blood group',
                    value: _privacy['bloodGroup'] ?? 'private',
                    onChanged: (v) => setState(
                      () => _privacy = {..._privacy, 'bloodGroup': v},
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _blood,
                    decoration: const InputDecoration(labelText: 'Blood group'),
                    items: [
                      for (final g in _bloodGroups)
                        DropdownMenuItem(value: g, child: Text(g)),
                    ],
                    onChanged: (v) => setState(() => _blood = v ?? 'Unknown'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _about,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'About'),
                  ),
                  const SizedBox(height: 8),
                  _SectionHeader(
                    title: 'Education',
                    privacyValue: _privacy['education'] ?? 'private',
                    onPrivacyChanged: (v) => setState(
                      () => _privacy = {..._privacy, 'education': v},
                    ),
                    onAdd: () {
                      if (_educations.length >= 8) return;
                      setState(() => _educations.add(_PairFields('', '')));
                    },
                  ),
                  ..._educations.asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.a,
                              decoration:
                                  const InputDecoration(labelText: 'Course'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: row.b,
                              decoration:
                                  const InputDecoration(labelText: 'School'),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              row.dispose();
                              _educations.removeAt(i);
                            }),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    );
                  }),
                  _SectionHeader(
                    title: 'Jobs',
                    privacyValue: _privacy['job'] ?? 'private',
                    onPrivacyChanged: (v) => setState(
                      () => _privacy = {..._privacy, 'job': v},
                    ),
                    onAdd: () {
                      if (_jobs.length >= 8) return;
                      setState(() => _jobs.add(_PairFields('', '')));
                    },
                  ),
                  ..._jobs.asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.a,
                              decoration:
                                  const InputDecoration(labelText: 'Title'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: row.b,
                              decoration:
                                  const InputDecoration(labelText: 'Place'),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              row.dispose();
                              _jobs.removeAt(i);
                            }),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    );
                  }),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12, top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.softFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show on family tree',
                          style: AppTheme.body(weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose education or job under your name on the tree card.',
                          style: AppTheme.body(size: 12, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Education'),
                              selected: _treeCardShow == 'education',
                              onSelected: (_) =>
                                  setState(() => _treeCardShow = 'education'),
                            ),
                            ChoiceChip(
                              label: const Text('Job'),
                              selected: _treeCardShow == 'job',
                              onSelected: (_) =>
                                  setState(() => _treeCardShow = 'job'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: AppTheme.body(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Save profile'),
                  ),
                  const SizedBox(height: 28),
                ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.body(weight: FontWeight.w900, size: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.body(size: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _PairFields {
  _PairFields(String a, String b)
      : a = TextEditingController(text: a),
        b = TextEditingController(text: b);

  final TextEditingController a;
  final TextEditingController b;

  void dispose() {
    a.dispose();
    b.dispose();
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: InkWell(
        onTap: onTap,
        child: Text(
          value ?? 'Select',
          style: AppTheme.body(
            color: value == null ? AppTheme.muted : AppTheme.ink,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onAdd,
    this.privacyValue,
    this.onPrivacyChanged,
  });

  final String title;
  final VoidCallback onAdd;
  final String? privacyValue;
  final ValueChanged<String>? onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTheme.body(weight: FontWeight.w800)),
          ),
          if (privacyValue != null && onPrivacyChanged != null) ...[
            _PrivacyToggle(
              value: privacyValue!,
              onChanged: onPrivacyChanged!,
            ),
            const SizedBox(width: 4),
          ],
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyFieldHeader extends StatelessWidget {
  const _PrivacyFieldHeader({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.body(size: 13, weight: FontWeight.w700),
            ),
          ),
          _PrivacyToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPublic = value == 'public';
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrivacyChip(
            label: 'Public',
            selected: isPublic,
            selectedColor: AppTheme.forest,
            onTap: () => onChanged('public'),
          ),
          _PrivacyChip(
            label: 'Private',
            selected: !isPublic,
            selectedColor: const Color(0xFF1E293B),
            onTap: () => onChanged('private'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyChip extends StatelessWidget {
  const _PrivacyChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppTheme.muted,
          ),
        ),
      ),
    );
  }
}
