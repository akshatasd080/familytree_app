import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/presentation/providers/theme_settings_provider.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';
import '../widgets/family_chat_panel.dart';
import '../widgets/family_room_panel.dart';

/// Messages inbox — Direct + Rooms, mockup-style UI.
class FamilyChatHubScreen extends StatefulWidget {
  const FamilyChatHubScreen({super.key});

  @override
  State<FamilyChatHubScreen> createState() => _FamilyChatHubScreenState();
}

class _FamilyChatHubScreenState extends State<FamilyChatHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _chatKey = GlobalKey<FamilyChatPanelState>();
  List<FamilyMember> _members = const [];
  bool _loading = true;
  bool _inThread = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
          await context.read<FamilyApiService>().listFamilyMembers(familyId);
      final data = res.data;
      List list = const [];
      if (data is Map && data['members'] is List) {
        list = data['members'] as List;
      } else if (data is List) {
        list = data;
      }
      _members = list
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _chatKey.currentState?.loadConversations();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startNewChat() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final candidates = _members
        .where((m) => (m.userId ?? '').isNotEmpty && m.isAlive)
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No family members available to chat')),
      );
      return;
    }
    final picked = await showModalBottomSheet<FamilyMember>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.shellBg,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Start a chat', style: AppTheme.display(size: 20)),
            const SizedBox(height: 8),
            Text(
              'Choose a family member',
              style: AppTheme.body(size: 13, color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            for (final m in candidates)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.forest.withValues(alpha: 0.12),
                  child: Text(
                    m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppTheme.forest,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  m.name,
                  style: AppTheme.body(weight: FontWeight.w700),
                ),
                subtitle: Text(
                  m.relationship ?? 'Member',
                  style: AppTheme.body(size: 12, color: AppTheme.muted),
                ),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final peerId = picked.userId;
    if (peerId == null || peerId.isEmpty) return;
    _tabs.animateTo(0);
    await _chatKey.currentState?.openChat(peerId);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeSettingsProvider>();
    final familyId = context.watch<FamilySessionProvider>().familyId;
    final myUserId = context.watch<AuthProvider>().user?.id;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final canOpenDrawer = !wide && Scaffold.maybeOf(context)?.hasDrawer == true;
    return Material(
      color: AppTheme.shellBg,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.22,
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
                      EdgeInsets.fromLTRB(canOpenDrawer ? 2 : 14, 6, 8, 4),
                  child: Row(
                    children: [
                      if (canOpenDrawer)
                        IconButton(
                          tooltip: 'Menu',
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: Icon(Icons.menu_rounded, color: AppTheme.ink),
                        ),
                      const FtBrandMark(size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messages',
                              style: AppTheme.display(
                                size: 22,
                                color: AppTheme.forestDark,
                              ),
                            ),
                            Text(
                              'Stay connected with your family ❤️',
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
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _load,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.forestDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_loading && _error == null && familyId != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.tabTrack,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.borderSoft),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      indicator: BoxDecoration(
                        color: AppTheme.forest,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.forest.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.forestDark,
                      labelStyle: AppTheme.body(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: AppTheme.body(
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('Direct'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.groups_outlined, size: 16),
                              SizedBox(width: 6),
                              Text('Rooms'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppTheme.forest.withValues(alpha: 0.25),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.people_alt_outlined,
                          size: 16,
                          color: AppTheme.forest,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppTheme.forest.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    _tabs.index == 0
                        ? 'Chat privately with family members'
                        : 'Group rooms for your family circles',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      size: 12,
                      color: AppTheme.muted,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: AppTheme.body(color: Colors.redAccent),
                              ),
                            ),
                          )
                        : familyId == null
                            ? Center(
                                child: Text(
                                  'Join or create a family to chat.',
                                  style: AppTheme.body(color: AppTheme.muted),
                                ),
                              )
                            : TabBarView(
                                controller: _tabs,
                                children: [
                                  FamilyChatPanel(
                                    key: _chatKey,
                                    familyId: familyId,
                                    styledInbox: true,
                                    onThreadChanged: (open) =>
                                        setState(() => _inThread = open),
                                  ),
                                  FamilyRoomPanel(
                                    familyId: familyId,
                                    members: _members,
                                    myUserId: myUserId,
                                  ),
                                ],
                              ),
              ),
            ],
          ),
          if (!_loading &&
              _error == null &&
              familyId != null &&
              _tabs.index == 0 &&
              !_inThread)
            Positioned(
              right: 18,
              bottom: 18 + MediaQuery.paddingOf(context).bottom,
              child: FloatingActionButton(
                heroTag: 'chat-hub-fab',
                tooltip: 'New chat',
                onPressed: _startNewChat,
                backgroundColor: AppTheme.forest,
                foregroundColor: Colors.white,
                elevation: 5,
                child: const Icon(Icons.add_comment_rounded),
              ),
            ),
        ],
      ),
    );
  }
}
