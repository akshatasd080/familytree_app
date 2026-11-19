import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';
import '../widgets/family_chat_panel.dart';
import '../widgets/family_room_panel.dart';

/// First-class Messenger-style inbox (Direct + Rooms).
/// Same APIs as the former Media → Chats tab — presentation only.
class FamilyChatHubScreen extends StatefulWidget {
  const FamilyChatHubScreen({super.key});

  @override
  State<FamilyChatHubScreen> createState() => _FamilyChatHubScreenState();
}

class _FamilyChatHubScreenState extends State<FamilyChatHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<FamilyMember> _members = const [];
  bool _loading = true;
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
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyId = context.watch<FamilySessionProvider>().familyId;
    final myUserId = context.watch<AuthProvider>().user?.id;

    return FtPage(
      title: 'Messages',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _loading
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
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.tabTrack,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: TabBar(
                              controller: _tabs,
                              indicator: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.ink.withValues(
                                      alpha: AppTheme.isDark ? 0.25 : 0.06,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: AppTheme.ink,
                              unselectedLabelColor: AppTheme.muted,
                              labelStyle: AppTheme.body(
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                              unselectedLabelStyle: AppTheme.body(
                                size: 13,
                                weight: FontWeight.w500,
                              ),
                              tabs: const [
                                Tab(text: 'Direct'),
                                Tab(text: 'Rooms'),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            _tabs.index == 0
                                ? 'Chat privately with family members'
                                : 'Group rooms for your family circles',
                            style: AppTheme.body(
                              size: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              FamilyChatPanel(familyId: familyId),
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
    );
  }
}
