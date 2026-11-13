import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/ft_widgets.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../family/data/family_api_service.dart';
import '../../../family/data/models/family_models.dart';
import '../../../family/presentation/providers/family_providers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<FamilyMember> _members = const [];
  List<Map<String, dynamic>> _invites = const [];
  List<Map<String, dynamic>> _notifications = const [];
  List<Map<String, dynamic>> _pending = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _norm(String? rel) =>
      (rel ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');

  int _estimateGenerations(List<FamilyMember> members) {
    final rels = members.map((m) => _norm(m.relationship)).toSet();
    var g = 1;
    if (rels.any((r) => ['father', 'mother', 'uncle', 'aunt'].contains(r))) {
      g = 2;
    }
    if (rels.any((r) =>
        ['grandfather', 'grandmother', 'grandma', 'grandpa'].contains(r))) {
      g = 3;
    }
    if (rels.any((r) => ['son', 'daughter'].contains(r))) {
      g = g < 2 ? 2 : g;
    }
    return g;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<FamilyApiService>();
    final session = context.read<FamilySessionProvider>();
    try {
      await session.loadMine();
      final results = await Future.wait([
        api.listMyInvitations(),
        api.listNotifications(),
      ]);

      final familyId = session.familyId;
      if (familyId != null) {
        final membersRes = await api.listFamilyMembers(familyId);
        final mdata = membersRes.data;
        List list = const [];
        List pending = const [];
        if (mdata is Map) {
          if (mdata['members'] is List) list = mdata['members'] as List;
          if (mdata['pendingInvitations'] is List) {
            pending = mdata['pendingInvitations'] as List;
          }
        } else if (mdata is List) {
          list = mdata;
        }
        _members = list
            .whereType<Map>()
            .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _pending = pending
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final inv = results[0].data;
      List invList = const [];
      if (inv is Map && inv['invitations'] is List) {
        invList = inv['invitations'] as List;
      } else if (inv is List) {
        invList = inv;
      }
      _invites = invList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final notif = results[1].data;
      List nList = const [];
      if (notif is Map && notif['notifications'] is List) {
        nList = notif['notifications'] as List;
      } else if (notif is List) {
        nList = notif;
      }
      _notifications = nList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  FamilyMember? _first(List<String> labels) {
    final set = labels.map(_norm).toSet();
    for (final m in _members) {
      if (set.contains(_norm(m.relationship))) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FamilySessionProvider>();
    final auth = context.watch<AuthProvider>();
    final family = session.current;
    final gens = _estimateGenerations(_members);
    final bannerUrl = mediaUrl(family?.avatar);
    final cols = context.gridCount(phone: 2, tablet: 2, wide: 4);

    return FtPage(
      title: family?.name ?? 'Dashboard',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ResponsiveBody(
                padding: EdgeInsets.fromLTRB(
                  context.isWide ? 28 : (context.isTablet ? 20 : 16),
                  6,
                  context.isWide ? 28 : (context.isTablet ? 20 : 16),
                  12,
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: AppTheme.body(color: Colors.red, size: 13),
                        ),
                      ),
                    _DashboardHero(
                      familyName: family?.name,
                      userName: auth.user?.name,
                      bannerUrl: bannerUrl,
                    ),
                    if (_invites.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      FtSectionCard(
                        color: AppTheme.amber50,
                        borderColor: AppTheme.amber200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invitations for you',
                              style: AppTheme.body(weight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            ..._invites.map((inv) {
                              final id = (inv['id'] ?? '').toString();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: AppTheme.amber200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${inv['invitedBy'] ?? 'A family admin'} invited you to ${inv['familyName'] ?? 'a family'} as ${inv['relationship'] ?? 'member'}',
                                        style: AppTheme.body(size: 13),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          FilledButton(
                                            onPressed: () async {
                                              await context
                                                  .read<FamilyApiService>()
                                                  .acceptInvitation(id);
                                              _load();
                                            },
                                            child: const Text('Accept'),
                                          ),
                                          OutlinedButton(
                                            onPressed: () async {
                                              await context
                                                  .read<FamilyApiService>()
                                                  .rejectInvitation(id);
                                              _load();
                                            },
                                            child: const Text('Reject'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth =
                            (constraints.maxWidth - (cols - 1) * 10) / cols;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: FtStatCard(
                                icon: Icons.groups,
                                value: '${_members.length}',
                                label: 'Members',
                                sub: 'In your family',
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: FtStatCard(
                                icon: Icons.account_tree,
                                value: '$gens',
                                label: 'Generations',
                                sub: 'On your tree',
                                tone: FtStatTone.purple,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: FtStatCard(
                                icon: Icons.mail_outline,
                                value: '${_pending.length}',
                                label: 'Pending invites',
                                sub: 'Awaiting OTP',
                                tone: FtStatTone.orange,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: FtStatCard(
                                icon: Icons.notifications_outlined,
                                value: '${_notifications.length}',
                                label: 'Notifications',
                                sub: 'Recent activity',
                                tone: FtStatTone.blue,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quick actions',
                      style: AppTheme.body(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ActionChip(Icons.account_tree, 'Tree',
                            () => context.go('/family/tree')),
                        _ActionChip(Icons.groups, 'Members',
                            () => context.go('/family/members')),
                        _ActionChip(Icons.photo_library, 'Media',
                            () => context.go('/family/media')),
                        _ActionChip(Icons.event, 'Events',
                            () => context.go('/family/events')),
                        _ActionChip(Icons.map_outlined, 'Map',
                            () => context.go('/family/map')),
                        _ActionChip(Icons.person, 'Profile',
                            () => context.go('/family/profile')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FtSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Family snapshot',
                                  style:
                                      AppTheme.body(weight: FontWeight.w800),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go('/family/tree'),
                                child: Text(
                                  'Open tree',
                                  style: AppTheme.body(
                                    weight: FontWeight.w700,
                                    color: AppTheme.forest,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _MiniTreePreview(
                            grandparents: [
                              _first(['grandfather', 'grandpa']),
                              _first(['grandmother', 'grandma']),
                            ].whereType<FamilyMember>().toList(),
                            parents: [
                              _first(['father', 'dad']),
                              _first(['mother', 'mom']),
                            ].whereType<FamilyMember>().toList(),
                            bottom: [
                              _first(['uncle']),
                              _members.cast<FamilyMember?>().firstWhere(
                                    (m) =>
                                        _norm(m?.relationship) ==
                                        'sitecreator',
                                    orElse: () => _members.isNotEmpty
                                        ? _members.first
                                        : null,
                                  ),
                              ..._members.where(
                                (m) => ['brother', 'sister']
                                    .contains(_norm(m.relationship)),
                              ),
                              _first(['aunt']),
                            ].whereType<FamilyMember>().toList(),
                          ),
                        ],
                      ),
                    ),
                    if (_notifications.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Activity',
                        style: AppTheme.body(weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ..._notifications.take(6).map(
                            (n) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FtSectionCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.notifications_outlined,
                                      color: AppTheme.forest,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        (n['message'] ??
                                                n['title'] ??
                                                'Notice')
                                            .toString(),
                                        style: AppTheme.body(size: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Proper welcome card: opaque text panel + right-side banner art only.
/// Default PNG has baked "Ankesh Prasad" on the left — that side is never shown.
class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.userName,
    this.familyName,
    this.bannerUrl,
  });

  final String? userName;
  final String? familyName;
  final String? bannerUrl;

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final usingFamilyPhoto = bannerUrl != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1FAE5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3D2914).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: phone ? 58 : 52,
              child: Container(
                color: usingFamilyPhoto
                    ? const Color(0xFF0F172A)
                    : Colors.white,
                padding: EdgeInsets.fromLTRB(
                  phone ? 14 : 20,
                  phone ? 12 : 16,
                  phone ? 8 : 12,
                  phone ? 12 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome back, ${userName ?? 'there'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(
                        size: phone ? 18 : 22,
                        color: usingFamilyPhoto
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    if (familyName != null &&
                        familyName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        familyName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: usingFamilyPhoto
                              ? const Color(0xFFD1FAE5)
                              : AppTheme.emerald600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      '“Family is not an important thing, it\'s everything.”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        size: 11,
                        color: usingFamilyPhoto
                            ? Colors.white.withValues(alpha: 0.9)
                            : const Color(0xFF475569),
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                    if (!phone) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Manage your family, preserve your roots, and keep everyone connected.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          size: 11,
                          color: usingFamilyPhoto
                              ? Colors.white.withValues(alpha: 0.8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              flex: phone ? 42 : 48,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: phone ? 112 : 132),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: usingFamilyPhoto
                          ? NetworkImage(bannerUrl!)
                          : const AssetImage(
                              'assets/images/family-banner-default.png',
                            ) as ImageProvider,
                      fit: BoxFit.cover,
                      alignment: usingFamilyPhoto
                          ? Alignment.center
                          : Alignment.centerRight,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/family-banner-default.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: usingFamilyPhoto
                              ? [
                                  const Color(0xFF0F172A),
                                  const Color(0xFF0F172A)
                                      .withValues(alpha: 0.35),
                                  Colors.transparent,
                                ]
                              : [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.transparent,
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = context.isPhone ? 96.0 : 110.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: w,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.forest, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(weight: FontWeight.w600, size: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTreePreview extends StatelessWidget {
  const _MiniTreePreview({
    required this.grandparents,
    required this.parents,
    required this.bottom,
  });

  final List<FamilyMember> grandparents;
  final List<FamilyMember> parents;
  final List<FamilyMember> bottom;

  @override
  Widget build(BuildContext context) {
    Widget row(List<FamilyMember> list, {String empty = ''}) {
      if (list.isEmpty) {
        return Text(
          empty,
          style: AppTheme.body(size: 11, color: AppTheme.muted),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: list.map((m) => _MiniNode(member: m)).toList(),
      );
    }

    return Column(
      children: [
        row(grandparents, empty: 'Add grandparents from Family Tree'),
        if (grandparents.isNotEmpty || parents.isNotEmpty)
          Container(
            width: 2,
            height: 12,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: const Color(0xFF34D399),
          ),
        row(parents, empty: 'Add parents from Family Tree'),
        if (parents.isNotEmpty || bottom.isNotEmpty)
          Container(
            width: 2,
            height: 12,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: const Color(0xFF34D399),
          ),
        row(bottom),
      ],
    );
  }
}

class _MiniNode extends StatelessWidget {
  const _MiniNode({required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final isMe =
        (member.relationship ?? '').toLowerCase().replaceAll(' ', '') ==
            'sitecreator';
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 150),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? AppTheme.forest : AppTheme.borderSoft,
            width: isMe ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.emerald100,
              child: Text(
                isMe
                    ? 'ME'
                    : (member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : '?'),
                style: AppTheme.body(
                  size: isMe ? 9 : 11,
                  weight: FontWeight.w800,
                  color: AppTheme.forest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 12, weight: FontWeight.w700),
                  ),
                  Text(
                    member.relationship ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 10, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
