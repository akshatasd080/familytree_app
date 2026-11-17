import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../../domain/ego_tree.dart';
import '../../domain/family_graph_layout.dart';
import '../../domain/profile_privacy.dart';

/// Web-parity profile panel opened from the Family Tree.
Future<void> showTreeMemberProfileSheet({
  required BuildContext context,
  required FamilyMember member,
  required String familyId,
  required List<FamilyMember> members,
  required List<Map<String, dynamic>> relationships,
  required String? focusUserId,
  required String? meUserId,
  required bool isAdmin,
  required Future<void> Function() onChanged,
  VoidCallback? onShowTheirTree,
  VoidCallback? onChat,
  Future<void> Function(FamilyMember member)? onMakeAdmin,
  ValueChanged<FamilyMember>? onOpenKin,
  String? treeRole,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TreeMemberProfileSheet(
      member: member,
      familyId: familyId,
      members: members,
      relationships: relationships,
      focusUserId: focusUserId,
      meUserId: meUserId,
      isAdmin: isAdmin,
      onChanged: onChanged,
      onShowTheirTree: onShowTheirTree,
      onChat: onChat,
      onMakeAdmin: onMakeAdmin,
      onOpenKin: onOpenKin,
      treeRole: treeRole,
    ),
  );
}

class _TreeMemberProfileSheet extends StatefulWidget {
  const _TreeMemberProfileSheet({
    required this.member,
    required this.familyId,
    required this.members,
    required this.relationships,
    required this.focusUserId,
    required this.meUserId,
    required this.isAdmin,
    required this.onChanged,
    this.onShowTheirTree,
    this.onChat,
    this.onMakeAdmin,
    this.onOpenKin,
    this.treeRole,
  });

  final FamilyMember member;
  final String familyId;
  final List<FamilyMember> members;
  final List<Map<String, dynamic>> relationships;
  final String? focusUserId;
  final String? meUserId;
  final bool isAdmin;
  final Future<void> Function() onChanged;
  final VoidCallback? onShowTheirTree;
  final VoidCallback? onChat;
  final Future<void> Function(FamilyMember member)? onMakeAdmin;
  final ValueChanged<FamilyMember>? onOpenKin;
  final String? treeRole;

  @override
  State<_TreeMemberProfileSheet> createState() =>
      _TreeMemberProfileSheetState();
}

class _TreeMemberProfileSheetState extends State<_TreeMemberProfileSheet> {
  String _tab = 'education';
  bool _photosLoading = false;
  List<Map<String, dynamic>> _photos = const [];
  late FamilyMember _member;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhotos());
  }

  bool get _isMe {
    final me = widget.meUserId;
    if (me == null || me.isEmpty) return false;
    return _member.userId == me || _member.id == me;
  }

  Map<String, dynamic> get _enriched {
    final map = <String, dynamic>{
      'id': _member.id,
      'userId': _member.userId,
      'user_id': _member.userId,
      'name': _member.name,
      'relationship': _member.relationship,
      'avatar': _member.avatar,
      'gender': _member.gender,
      'location': _member.location,
      'phone': _member.phone,
      'email': _member.email,
      'profileInfo': _member.profileInfo,
      'profile_info': _member.profileInfo,
    };
    return enrichMemberProfile(map);
  }

  String get _roleLabel {
    final role = (widget.treeRole ?? '').trim();
    if (role.isNotEmpty) return role;
    final rel = (_member.relationship ?? '').trim();
    if (rel.isNotEmpty &&
        rel.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '') != 'sitecreator') {
      return rel;
    }
    return 'Family';
  }

  Map<String, List<FamilyMember>> get _kin {
    final maps = widget.members
        .map(
          (m) => <String, dynamic>{
            'id': m.id,
            'userId': m.userId,
            'user_id': m.userId,
            'name': m.name,
            'relationship': m.relationship,
            'avatar': m.avatar,
            'gender': m.gender,
            'profileInfo': m.profileInfo,
            'profile_info': m.profileInfo,
          },
        )
        .toList();
    final layout = buildFamilyLayout(
      maps,
      widget.relationships,
      widget.focusUserId,
    );
    final raw = layout.kinOf(_member.id);
    final byId = {for (final m in widget.members) m.id: m};
    List<FamilyMember> resolve(String key) {
      final list = raw[key] ?? const <MemberMap>[];
      final out = <FamilyMember>[];
      for (final item in list) {
        final id = (item['id'] ?? '').toString();
        final found = byId[id];
        if (found != null) {
          out.add(found);
        } else {
          out.add(FamilyMember.fromJson(item));
        }
      }
      return out;
    }

    return {
      'Parents': resolve('parents'),
      'Spouse': resolve('spouses'),
      'Children': resolve('children'),
      'Siblings': resolve('siblings'),
    };
  }

  Future<void> _loadPhotos() async {
    final userId = _member.userId;
    if (userId == null || userId.isEmpty) return;
    setState(() => _photosLoading = true);
    try {
      final res = await context.read<FamilyApiService>().listFamilyMedia(
            widget.familyId,
            params: {'authorId': userId},
          );
      final data = res.data;
      List list = const [];
      if (data is Map && data['media'] is List) {
        list = data['media'] as List;
      } else if (data is List) {
        list = data;
      }
      final photos = list
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
      setState(() => _photos = photos);
    } catch (_) {
      if (!mounted) return;
      setState(() => _photos = const []);
    } finally {
      if (mounted) setState(() => _photosLoading = false);
    }
  }

  Future<void> _toggleAdmin() async {
    final fn = widget.onMakeAdmin;
    if (fn == null) return;
    await fn(_member);
    if (!mounted) return;
    setState(() {
      _member = _member.copyWith(isAdmin: !_member.isAdmin);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enriched = _enriched;
    final url = mediaUrl(_member.avatar);
    final privacy = privacyOfMember(profileInfo: _member.profileInfo);
    final canSeePrivate = canSeePrivateFields(
      isAdmin: widget.isAdmin,
      isSelf: _isMe,
    );
    final phonePrivate = isFieldPrivate(
      privacy,
      'phone',
      canSeePrivate: canSeePrivate,
    );
    final dobPrivate = isFieldPrivate(
      privacy,
      'dateOfBirth',
      canSeePrivate: canSeePrivate,
    );
    final educationPrivate = isFieldPrivate(
      privacy,
      'education',
      canSeePrivate: canSeePrivate,
    );
    final jobPrivate = isFieldPrivate(
      privacy,
      'job',
      canSeePrivate: canSeePrivate,
    );
    final bloodPrivate = isFieldPrivate(
      privacy,
      'bloodGroup',
      canSeePrivate: canSeePrivate,
    );
    final phone = (_member.phone ?? enriched['phone'] ?? '')
        .toString()
        .trim();
    final email = _member.displayEmail;
    final location = (_member.location ?? '').trim();
    final dob = (enriched['dateOfBirth'] ??
            _member.profileInfo['dateOfBirth'] ??
            '')
        .toString()
        .trim();
    final blood = (enriched['bloodGroup'] ?? '').toString().trim();
    final educations = (enriched['educations'] is List)
        ? (enriched['educations'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) =>
                (e['course'] ?? '').toString().isNotEmpty ||
                (e['school'] ?? '').toString().isNotEmpty)
            .toList()
        : <Map<String, dynamic>>[];
    final jobs = (enriched['jobs'] is List)
        ? (enriched['jobs'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) =>
                (e['title'] ?? '').toString().isNotEmpty ||
                (e['place'] ?? '').toString().isNotEmpty)
            .toList()
        : <Map<String, dynamic>>[];
    final educationText = (enriched['education'] ?? '').toString().trim();
    final occupation = (enriched['occupation'] ?? '').toString().trim();
    final workplace = (enriched['workplace'] ?? '').toString().trim();
    final kin = _kin;
    final kinRows = kin.entries.where((e) => e.value.isNotEmpty).toList();
    final canAdmin = widget.isAdmin &&
        _member.hasLoginAccount &&
        !_member.isOwner &&
        !_isMe;
    final canChat = widget.onChat != null &&
        _member.hasLoginAccount &&
        !_isMe &&
        _member.isAlive;
    final phoneLabel = phone.isNotEmpty
        ? phone
        : privateOrEmptyLabel(
            isPrivate: phonePrivate,
            emptyLabel: 'Mobile not added',
          );
    final dobLabel = dob.isNotEmpty
        ? dob
        : privateOrEmptyLabel(
            isPrivate: dobPrivate,
            emptyLabel: 'Date of birth not added',
          );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF6F4EF),
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_handle, size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Profile',
                          style: AppTheme.body(
                            size: 12,
                            weight: FontWeight.w700,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor:
                                AppTheme.forest.withValues(alpha: 0.12),
                            backgroundImage:
                                url != null ? NetworkImage(url) : null,
                            child: url == null
                                ? Text(
                                    _member.name.isNotEmpty
                                        ? _member.name[0].toUpperCase()
                                        : '?',
                                    style: AppTheme.display(
                                      size: 22,
                                      color: AppTheme.forest,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      _member.name,
                                      style: AppTheme.display(size: 20),
                                    ),
                                    if (_isMe)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFBBF24),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    if (_member.isAdmin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: const Color(0xFFBAE6FD),
                                          ),
                                        ),
                                        child: Text(
                                          _member.isOwner ? 'OWNER' : 'ADMIN',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0369A1),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _roleLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (canAdmin) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0369A1),
                              side: const BorderSide(color: Color(0xFF7DD3FC)),
                              backgroundColor: const Color(0xFFF0F9FF),
                            ),
                            onPressed: _toggleAdmin,
                            icon: const Icon(Icons.shield_outlined, size: 16),
                            label: Text(
                              _member.isAdmin
                                  ? 'Remove family admin'
                                  : 'Make family admin',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.place_outlined,
                        value: location.isEmpty ? 'Location not added' : location,
                        muted: location.isEmpty,
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        value: phoneLabel,
                        muted: phone.isEmpty,
                      ),
                      if (email.isNotEmpty)
                        _InfoRow(icon: Icons.mail_outline, value: email),
                      _InfoRow(
                        icon: Icons.cake_outlined,
                        value: dobLabel,
                        muted: dob.isEmpty,
                      ),
                      if (kinRows.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'FAMILY',
                          style: AppTheme.body(
                            size: 11,
                            weight: FontWeight.w800,
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final row in kinRows) ...[
                          Text(
                            row.key,
                            style: AppTheme.body(
                              size: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (final person in row.value)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    AppTheme.forest.withValues(alpha: 0.12),
                                backgroundImage: mediaUrl(person.avatar) != null
                                    ? NetworkImage(mediaUrl(person.avatar)!)
                                    : null,
                                child: mediaUrl(person.avatar) == null
                                    ? Text(
                                        person.name.isNotEmpty
                                            ? person.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(fontSize: 11),
                                      )
                                    : null,
                              ),
                              title: Text(person.name),
                              onTap: widget.onOpenKin == null
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      widget.onOpenKin!(person);
                                    },
                            ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final tab in const [
                              ('education', 'Education', Icons.school_outlined),
                              ('photos', 'Photos', Icons.photo_library_outlined),
                              ('job', 'Job', Icons.work_outline),
                              ('blood', 'Blood group', Icons.water_drop_outlined),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(tab.$3, size: 14),
                                      const SizedBox(width: 4),
                                      Text(tab.$2),
                                    ],
                                  ),
                                  selected: _tab == tab.$1,
                                  selectedColor: AppTheme.forest,
                                  labelStyle: TextStyle(
                                    color: _tab == tab.$1
                                        ? Colors.black
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _tab = tab.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 140),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: _buildTabBody(
                          educations: educations,
                          educationText: educationText,
                          educationPrivate: educationPrivate,
                          jobs: jobs,
                          occupation: occupation,
                          workplace: workplace,
                          jobPrivate: jobPrivate,
                          blood: blood,
                          bloodPrivate: bloodPrivate,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  color: const Color(0xFFFBF9F6),
                  child: Column(
                    children: [
                      if (widget.onShowTheirTree != null &&
                          _member.hasLoginAccount &&
                          !_isMe)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.forest,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onShowTheirTree!();
                            },
                            icon: const Icon(Icons.account_tree_outlined),
                            label: const Text('Show their tree'),
                          ),
                        ),
                      if (canChat) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onChat!();
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Chat'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody({
    required List<Map<String, dynamic>> educations,
    required String educationText,
    required bool educationPrivate,
    required List<Map<String, dynamic>> jobs,
    required String occupation,
    required String workplace,
    required bool jobPrivate,
    required String blood,
    required bool bloodPrivate,
  }) {
    switch (_tab) {
      case 'photos':
        if (_photosLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_photos.isEmpty) {
          return const _EmptyTab(
            icon: Icons.photo_library_outlined,
            message: 'No photos shared yet.',
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _photos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemBuilder: (_, i) {
            final photo = _photos[i];
            final path = (photo['filePath'] ??
                    photo['file_path'] ??
                    photo['url'] ??
                    photo['path'] ??
                    '')
                .toString();
            final src = mediaUrl(path);
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: src == null
                  ? Container(color: const Color(0xFFE2E8F0))
                  : Image.network(src, fit: BoxFit.cover),
            );
          },
        );
      case 'job':
        if (jobPrivate) {
          return const _EmptyTab(
            icon: Icons.work_outline,
            message: 'Job is private',
          );
        }
        if (jobs.isNotEmpty) {
          return Column(
            children: [
              for (final job in jobs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((job['title'] ?? 'Job').toString()),
                  subtitle: (job['place'] ?? '').toString().isEmpty
                      ? null
                      : Text(job['place'].toString()),
                ),
            ],
          );
        }
        if (occupation.isNotEmpty || workplace.isNotEmpty) {
          return Text(
            [occupation, workplace].where((e) => e.isNotEmpty).join(' · '),
          );
        }
        return const _EmptyTab(
          icon: Icons.work_outline,
          message: 'No job added yet.',
        );
      case 'blood':
        if (bloodPrivate && blood.isEmpty) {
          return const _EmptyTab(
            icon: Icons.water_drop_outlined,
            message: 'Blood group is private',
          );
        }
        if (blood.isNotEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.water_drop, color: Color(0xFFF43F5E)),
                const SizedBox(height: 4),
                Text(
                  'BLOOD GROUP',
                  style: AppTheme.body(
                    size: 10,
                    weight: FontWeight.w800,
                    color: const Color(0xFFFB7185),
                  ),
                ),
                const SizedBox(height: 4),
                Text(blood, style: AppTheme.display(size: 28)),
              ],
            ),
          );
        }
        return const _EmptyTab(
          icon: Icons.water_drop_outlined,
          message: 'Blood group not shared.',
        );
      case 'education':
      default:
        if (educationPrivate) {
          return const _EmptyTab(
            icon: Icons.school_outlined,
            message: 'Education is private',
          );
        }
        if (educations.isNotEmpty) {
          return Column(
            children: [
              for (final edu in educations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((edu['course'] ?? 'Education').toString()),
                  subtitle: (edu['school'] ?? '').toString().isEmpty
                      ? null
                      : Text(edu['school'].toString()),
                ),
            ],
          );
        }
        if (educationText.isNotEmpty) {
          return Text(educationText);
        }
        return const _EmptyTab(
          icon: Icons.school_outlined,
          message: 'No education added yet.',
        );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTheme.body(
                size: 13,
                color: muted ? AppTheme.muted : AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTheme.body(size: 13, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
