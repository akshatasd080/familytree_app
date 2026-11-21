import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_widgets.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../family/data/family_api_service.dart';
import '../../../family/data/models/family_models.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../settings/presentation/providers/theme_settings_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<FamilyMember> _members = const [];
  List<Map<String, dynamic>> _invites = const [];
  List<Map<String, dynamic>> _notifications = const [];
  List<Map<String, dynamic>> _recentPosts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _norm(String? rel) =>
      (rel ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');

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
        final familyResults = await Future.wait([
          api.listFamilyMembers(familyId),
          api.listFamilyMedia(familyId),
        ]);
        final mdata = familyResults[0].data;
        List list = const [];
        if (mdata is Map) {
          if (mdata['members'] is List) list = mdata['members'] as List;
        } else if (mdata is List) {
          list = mdata;
        }
        _members = list
            .whereType<Map>()
            .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        final mediaData = familyResults[1].data;
        List mediaList = const [];
        if (mediaData is Map && mediaData['media'] is List) {
          mediaList = mediaData['media'] as List;
        } else if (mediaData is List) {
          mediaList = mediaData;
        }
        _recentPosts = mediaList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .take(8)
            .toList();
      } else {
        _recentPosts = const [];
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

      if (mounted) {
        context.read<FamilyNoticesUnreadProvider>().refresh();
        context
            .read<FamilyChatUnreadProvider>()
            .refresh(families: session.families);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _memberGender(FamilyMember m) {
    final raw = (m.gender ?? m.profileInfo['gender'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw == 'male' || raw == 'female') return raw;
    final r = _norm(m.relationship);
    if ([
      'mother',
      'sister',
      'daughter',
      'wife',
      'aunt',
      'grandmother',
      'spouse',
      'partner',
    ].contains(r)) {
      return 'female';
    }
    return 'male';
  }

  DateTime? _parseDob(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
      return DateTime.tryParse(s.substring(0, 10));
    }
    return DateTime.tryParse(s);
  }

  ({int years, int months, int days, int totalDays})? _ageParts(DateTime dob) {
    final now = DateTime.now();
    if (dob.isAfter(now)) return null;
    var years = now.year - dob.year;
    var months = now.month - dob.month;
    var days = now.day - dob.day;
    if (days < 0) {
      months -= 1;
      final prev = DateTime(now.year, now.month, 0);
      days += prev.day;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years < 0 || years >= 130) return null;
    final totalDays = now.difference(dob).inDays;
    return (years: years, months: months, days: days, totalDays: totalDays);
  }

  Map<String, dynamic> _familyOverview() {
    var male = 0;
    var female = 0;
    final livingWithAge = <Map<String, dynamic>>[];
    for (final m in _members) {
      final alive = m.isAlive && m.profileInfo['isAlive'] != false;
      if (!alive) continue;
      final gender = _memberGender(m);
      if (gender == 'male') {
        male += 1;
      } else if (gender == 'female') {
        female += 1;
      }
      final dob = _parseDob(
        m.profileInfo['dateOfBirth'] ?? m.profileInfo['date_of_birth'],
      );
      if (dob == null) continue;
      final age = _ageParts(dob);
      if (age == null) continue;
      livingWithAge.add({
        'id': m.id,
        'name': m.name,
        'age': age,
        'label': '${age.years}y ${age.months}m ${age.days}d',
        'totalDays': age.totalDays,
      });
    }
    livingWithAge.sort(
      (a, b) => (b['totalDays'] as int).compareTo(a['totalDays'] as int),
    );
    final totalGender = male + female;
    return {
      'male': male,
      'female': female,
      'malePct': totalGender == 0 ? 50 : ((male / totalGender) * 100).round(),
      'femalePct':
          totalGender == 0 ? 50 : ((female / totalGender) * 100).round(),
      'oldest': livingWithAge.isEmpty ? null : livingWithAge.first,
      'youngest': livingWithAge.isEmpty ? null : livingWithAge.last,
    };
  }

  int get _unreadNotices =>
      context.watch<FamilyNoticesUnreadProvider>().unreadCount;

  int get _unreadChats =>
      context.watch<FamilyChatUnreadProvider>().unreadCount;

  int get _notificationBadgeCount {
    var n = 0;
    for (final item in _notifications) {
      final read = item['is_read'] == true || item['isRead'] == true;
      if (!read) n += 1;
    }
    return n + _unreadNotices;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeSettingsProvider>();
    final session = context.watch<FamilySessionProvider>();
    final auth = context.watch<AuthProvider>();
    final family = session.current;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final canOpenDrawer = !wide && Scaffold.maybeOf(context)?.hasDrawer == true;
    final firstName = (auth.user?.name ?? 'there').split(' ').first;
    final userAvatar = mediaUrl(
      _members
          .cast<FamilyMember?>()
          .firstWhere(
            (m) =>
                m?.userId == auth.user?.id ||
                _norm(m?.relationship) == 'sitecreator',
            orElse: () => null,
          )
          ?.avatar,
    );

    return Material(
      color: AppTheme.shellBg,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: AppTheme.isDark ? 0.08 : 0.16,
                child: Image.asset(
                  'assets/images/tree_canvas_bg.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(canOpenDrawer ? 2 : 14, 6, 8, 8),
                  child: Row(
                    children: [
                      if (canOpenDrawer)
                        IconButton(
                          tooltip: 'Menu',
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: Icon(Icons.menu_rounded, color: AppTheme.ink),
                        ),
                      const FtBrandMark(size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              family?.name ?? 'Family Tree',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.display(
                                size: 22,
                                color: AppTheme.forestDark,
                              ),
                            ),
                            Text(
                              'Our Family • Our Roots • Forever ❤️',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(
                                size: 11,
                                color: AppTheme.muted,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            tooltip: 'Notifications',
                            onPressed: () => context.push('/family/activity'),
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: AppTheme.ink,
                            ),
                          ),
                          if (_notificationBadgeCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: FtCountBadge(
                                count: _notificationBadgeCount,
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            context.isWide ? 28 : 16,
                            4,
                            context.isWide ? 28 : 16,
                            100,
                          ),
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _error!,
                                  style:
                                      AppTheme.body(color: Colors.red, size: 13),
                                ),
                              ),
                            _WelcomeHero(
                              userName: firstName,
                              polaroidUrl: userAvatar,
                            ),
                            if (_invites.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _InvitesCard(
                                invites: _invites,
                                onAccept: (id) async {
                                  await context
                                      .read<FamilyApiService>()
                                      .acceptInvitation(id);
                                  _load();
                                },
                                onReject: (id) async {
                                  await context
                                      .read<FamilyApiService>()
                                      .rejectInvitation(id);
                                  _load();
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            _QuickActionsGrid(
                              onTree: () => context.openShell('/family/tree'),
                              onFeed: () => context.openShell('/family/media'),
                              onChat: () => context.openShell('/family/chat'),
                              onEvents: () =>
                                  context.openShell('/family/events'),
                              onMap: () => context.openShell('/family/map'),
                              onProfile: () =>
                                  context.openShell('/family/profile'),
                              chatBadge: _unreadChats,
                            ),
                            const SizedBox(height: 16),
                            _FamilyOverviewCard(overview: _familyOverview()),
                            if (_recentPosts.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _LatestFromFamily(
                                posts: _recentPosts,
                                onOpenFeed: () =>
                                    context.openShell('/family/media'),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 18 + MediaQuery.paddingOf(context).bottom,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  heroTag: 'dashboard-chat-fab',
                  tooltip: 'Chat',
                  onPressed: () => context.openShell('/family/chat'),
                  backgroundColor: AppTheme.forest,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  child: const Icon(Icons.chat_bubble_rounded),
                ),
                if (_unreadChats > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: FtCountBadge(count: _unreadChats, compact: true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({
    required this.userName,
    this.polaroidUrl,
  });

  final String userName;
  final String? polaroidUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF2F6B4F),
            Color(0xFF3D8B63),
            Color(0xFF4FA37A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F6B4F).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: -10,
            bottom: -16,
            child: Opacity(
              opacity: 0.35,
              child: Icon(
                Icons.park_rounded,
                size: 120,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome back, $userName 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.display(
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '“Family is not an important thing, it’s everything.”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.92),
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Transform.rotate(
                  angle: 0.08,
                  child: Container(
                    width: 72,
                    height: 86,
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: polaroidUrl != null
                                ? Image.network(
                                    polaroidUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _polaroidFallback(),
                                  )
                                : _polaroidFallback(),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: -2,
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: const Color(0xFFE11D48).withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _polaroidFallback() {
    return Container(
      color: const Color(0xFFE8F5E9),
      alignment: Alignment.center,
      child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
        style: AppTheme.display(size: 28, color: AppTheme.forest),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onTree,
    required this.onFeed,
    required this.onChat,
    required this.onEvents,
    required this.onMap,
    required this.onProfile,
    this.chatBadge = 0,
  });

  final VoidCallback onTree;
  final VoidCallback onFeed;
  final VoidCallback onChat;
  final VoidCallback onEvents;
  final VoidCallback onMap;
  final VoidCallback onProfile;
  final int chatBadge;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Color, Color, VoidCallback, int)>[
      (
        Icons.account_tree_rounded,
        'Tree',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
        onTree,
        0,
      ),
      (
        Icons.auto_awesome_mosaic_rounded,
        'Feed',
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
        onFeed,
        0,
      ),
      (
        Icons.chat_bubble_rounded,
        'Chat',
        const Color(0xFFFCE4EC),
        const Color(0xFFC2185B),
        onChat,
        chatBadge,
      ),
      (
        Icons.event_rounded,
        'Events',
        const Color(0xFFFFF3E0),
        const Color(0xFFEF6C00),
        onEvents,
        0,
      ),
      (
        Icons.map_rounded,
        'Map',
        const Color(0xFFF3E5F5),
        const Color(0xFF7B1FA2),
        onMap,
        0,
      ),
      (
        Icons.person_rounded,
        'Profile',
        const Color(0xFFE0F2F1),
        const Color(0xFF00796B),
        onProfile,
        0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final w = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: w,
                child: _QuickActionTile(
                  icon: item.$1,
                  label: item.$2,
                  soft: item.$3,
                  accent: item.$4,
                  onTap: item.$5,
                  badge: item.$6,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.soft,
    required this.accent,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final Color soft;
  final Color accent;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderSoft),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.body(weight: FontWeight.w800, size: 14),
                ),
              ),
              if (badge > 0) ...[
                FtCountBadge(count: badge),
                const SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyOverviewCard extends StatelessWidget {
  const _FamilyOverviewCard({required this.overview});

  final Map<String, dynamic> overview;

  @override
  Widget build(BuildContext context) {
    final male = overview['male'] as int? ?? 0;
    final female = overview['female'] as int? ?? 0;
    final malePct =
        male + female == 0 ? 50 : (overview['malePct'] as int? ?? 50);
    final femalePct = male + female == 0 ? 50 : 100 - malePct;
    final oldest = overview['oldest'] as Map?;
    final youngest = overview['youngest'] as Map?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSoft),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2A24).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Family overview',
                  style: AppTheme.body(weight: FontWeight.w800, size: 15),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.softFill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$male Male • $female Female',
                  style: AppTheme.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppTheme.mutedSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: malePct.clamp(1, 99),
                    child: Container(color: const Color(0xFF60A5FA)),
                  ),
                  Expanded(
                    flex: femalePct.clamp(1, 99),
                    child: Container(color: const Color(0xFFD670B1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Oldest: ${oldest == null ? '—' : '${oldest['name']} (${oldest['label']})'}',
            style: AppTheme.body(size: 12, color: AppTheme.mutedSoft),
          ),
          const SizedBox(height: 4),
          Text(
            'Youngest: ${youngest == null ? '—' : '${youngest['name']} (${youngest['label']})'}',
            style: AppTheme.body(size: 12, color: AppTheme.mutedSoft),
          ),
        ],
      ),
    );
  }
}

class _LatestFromFamily extends StatelessWidget {
  const _LatestFromFamily({
    required this.posts,
    required this.onOpenFeed,
  });

  final List<Map<String, dynamic>> posts;
  final VoidCallback onOpenFeed;

  String? _url(Map<String, dynamic> item) => mediaUrl(
        (item['url'] ??
                item['image'] ??
                item['path'] ??
                item['file_path'] ??
                item['filePath'])
            ?.toString(),
      );

  String _title(Map<String, dynamic> item) {
    final caption = (item['caption'] ?? '').toString().trim();
    if (caption.isNotEmpty) return caption;
    final user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'] as Map)
        : null;
    final author = (item['authorName'] ??
            item['uploadedByName'] ??
            user?['name'] ??
            'Family')
        .toString();
    return '$author shared a moment';
  }

  String _date(Map<String, dynamic> item) {
    final raw =
        item['createdAt'] ?? item['created_at'] ?? item['uploadedAt'];
    final when = DateTime.tryParse('$raw');
    if (when == null) return '';
    return DateFormat.MMMd().add_y().format(when.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Latest from family',
                style: AppTheme.body(weight: FontWeight.w800, size: 15),
              ),
            ),
            TextButton(
              onPressed: onOpenFeed,
              child: Text(
                'See all →',
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
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final post = posts[i];
              final url = _url(post);
              return InkWell(
                onTap: onOpenFeed,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url != null)
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.cream,
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.forest,
                                AppTheme.emerald600,
                              ],
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(post),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(
                                size: 13,
                                weight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            if (_date(post).isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _date(post),
                                style: AppTheme.body(
                                  size: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InvitesCard extends StatelessWidget {
  const _InvitesCard({
    required this.invites,
    required this.onAccept,
    required this.onReject,
  });

  final List<Map<String, dynamic>> invites;
  final Future<void> Function(String id) onAccept;
  final Future<void> Function(String id) onReject;

  @override
  Widget build(BuildContext context) {
    return FtSectionCard(
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
          ...invites.map((inv) {
            final id = (inv['id'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.amber200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${inv['invitedBy'] ?? 'A family admin'} invited you to ${inv['familyName'] ?? 'a family'} as ${inv['relationship'] ?? 'member'}',
                      style: AppTheme.body(size: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => onAccept(id),
                          child: const Text('Accept'),
                        ),
                        OutlinedButton(
                          onPressed: () => onReject(id),
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
    );
  }
}
