import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../data/family_api_service.dart';

/// 1:1 family chat — conversation list + message thread (web FamilyTree / Media parity).
class FamilyChatPanel extends StatefulWidget {
  const FamilyChatPanel({
    super.key,
    required this.familyId,
    this.initialPeerUserId,
    this.compact = false,
    this.onClose,
  });

  final String familyId;
  final String? initialPeerUserId;
  final bool compact;
  final VoidCallback? onClose;

  @override
  State<FamilyChatPanel> createState() => FamilyChatPanelState();
}

class FamilyChatPanelState extends State<FamilyChatPanel> {
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _peer;
  String? _activePeerId;
  final _draft = TextEditingController();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _loadingList = true;
  bool _loadingThread = false;
  bool _sending = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadConversations();
      final peer = widget.initialPeerUserId;
      if (peer != null && peer.isNotEmpty) {
        await openChat(peer);
      }
    });
  }

  @override
  void didUpdateWidget(covariant FamilyChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyId != widget.familyId) {
      _activePeerId = null;
      _peer = null;
      _messages = const [];
      loadConversations();
    }
    final peer = widget.initialPeerUserId;
    if (peer != null &&
        peer.isNotEmpty &&
        peer != oldWidget.initialPeerUserId) {
      openChat(peer);
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> loadConversations() async {
    setState(() => _loadingList = true);
    try {
      final res = await context
          .read<FamilyApiService>()
          .listFamilyChatConversations(widget.familyId);
      final data = res.data;
      List list = const [];
      if (data is Map && data['conversations'] is List) {
        list = data['conversations'] as List;
      }
      _conversations = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      _conversations = const [];
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> openChat(String peerUserId) async {
    if (peerUserId.isEmpty) return;
    setState(() {
      _activePeerId = peerUserId;
      _loadingThread = true;
      _messages = const [];
      _peer = null;
    });
    try {
      final res = await context
          .read<FamilyApiService>()
          .listFamilyChatMessages(widget.familyId, peerUserId);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      _peer = data['peer'] is Map
          ? Map<String, dynamic>.from(data['peer'] as Map)
          : {'userId': peerUserId, 'name': 'Chat'};
      final msgs = data['messages'] is List ? data['messages'] as List : [];
      _messages = msgs
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      await loadConversations();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      setState(() => _activePeerId = null);
    } finally {
      if (mounted) setState(() => _loadingThread = false);
    }
  }

  void closeThread() {
    setState(() {
      _activePeerId = null;
      _peer = null;
      _messages = const [];
      _draft.clear();
    });
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    final peerId = _activePeerId;
    if (body.isEmpty || peerId == null) return;
    setState(() => _sending = true);
    try {
      final res = await context
          .read<FamilyApiService>()
          .sendFamilyChatMessage(widget.familyId, peerId, body);
      final data = res.data;
      Map<String, dynamic>? chat;
      if (data is Map && data['chat'] is Map) {
        chat = Map<String, dynamic>.from(data['chat'] as Map);
      } else if (data is Map) {
        chat = Map<String, dynamic>.from(data);
      }
      if (chat != null) {
        setState(() {
          _messages = [..._messages, chat!];
          _draft.clear();
        });
        _scrollToEnd();
      }
      loadConversations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _conversations;
    return _conversations.where((c) {
      final hay = [
        c['name'],
        c['location'],
        c['relationship'],
      ].whereType<Object>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_activePeerId != null) return _buildThread();
    return _buildList();
  }

  Widget _buildList() {
    final list = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search family…',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                filled: true,
                fillColor: AppTheme.tabTrack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        if (_loadingList)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (list.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No family members to chat with yet.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(size: 13, color: AppTheme.muted),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = list[i];
                final name = (c['name'] ?? 'Member').toString();
                final last = c['lastMessage'] is Map
                    ? (c['lastMessage']['body'] ?? '').toString()
                    : (c['relationship'] ?? c['location'] ?? 'Say hello')
                        .toString();
                final unread = c['unread'] is int
                    ? c['unread'] as int
                    : int.tryParse('${c['unread']}') ?? 0;
                final avatar = mediaUrl(c['avatar']?.toString());
                final peerId =
                    (c['userId'] ?? c['user_id'] ?? '').toString();
                return ListTile(
                  onTap: () => openChat(peerId),
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.accentPink.withValues(alpha: 0.15),
                    backgroundImage:
                        avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: AppTheme.accentPink,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(weight: FontWeight.w700, size: 13),
                  ),
                  subtitle: Text(
                    last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 11, color: AppTheme.muted),
                  ),
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPink,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: AppTheme.accentPink,
                        ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildThread() {
    final peerName = (_peer?['name'] ?? 'Chat').toString();
    final avatar = mediaUrl(_peer?['avatar']?.toString());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: closeThread,
                icon: const Icon(Icons.arrow_back),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.accentPink.withValues(alpha: 0.15),
                backgroundImage:
                    avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(
                        peerName.isNotEmpty
                            ? peerName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentPink,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(weight: FontWeight.w800, size: 13),
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingThread
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Start chatting',
                        style: AppTheme.body(size: 12, color: AppTheme.muted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final fromMe = m['fromMe'] == true ||
                            m['from_me'] == true ||
                            m['mine'] == true;
                        final body =
                            (m['body'] ?? m['message'] ?? '').toString();
                        return Align(
                          alignment: fromMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.sizeOf(context).width * 0.72,
                            ),
                            decoration: BoxDecoration(
                              color: fromMe
                                  ? AppTheme.accentPink
                                  : AppTheme.card,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(fromMe ? 16 : 4),
                                bottomRight:
                                    Radius.circular(fromMe ? 4 : 16),
                              ),
                              border: fromMe
                                  ? null
                                  : Border.all(color: AppTheme.borderSoft),
                            ),
                            child: Text(
                              body,
                              style: AppTheme.body(
                                size: 12,
                                color: fromMe ? Colors.white : AppTheme.ink,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _draft,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.tabTrack,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentPink,
                  foregroundColor: Colors.white,
                ),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Floating dock for Tree screen (closed / minimized / expanded).
enum FamilyChatDockMode { closed, minimized, expanded }

class FamilyChatDock extends StatefulWidget {
  const FamilyChatDock({
    super.key,
    required this.familyId,
    this.initialPeerUserId,
    this.mode = FamilyChatDockMode.closed,
    this.onModeChanged,
  });

  final String familyId;
  final String? initialPeerUserId;
  final FamilyChatDockMode mode;
  final ValueChanged<FamilyChatDockMode>? onModeChanged;

  @override
  State<FamilyChatDock> createState() => _FamilyChatDockState();
}

class _FamilyChatDockState extends State<FamilyChatDock> {
  late FamilyChatDockMode _mode;
  final _chatKey = GlobalKey<FamilyChatPanelState>();

  @override
  void initState() {
    super.initState();
    _mode = widget.initialPeerUserId != null
        ? FamilyChatDockMode.expanded
        : widget.mode;
  }

  @override
  void didUpdateWidget(covariant FamilyChatDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPeerUserId != null &&
        widget.initialPeerUserId != oldWidget.initialPeerUserId) {
      setState(() => _mode = FamilyChatDockMode.expanded);
    }
  }

  void _setMode(FamilyChatDockMode mode) {
    setState(() => _mode = mode);
    widget.onModeChanged?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == FamilyChatDockMode.closed) {
      return Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton(
          heroTag: 'family_chat_fab',
          backgroundColor: AppTheme.accentPink,
          foregroundColor: Colors.white,
          onPressed: () => _setMode(FamilyChatDockMode.expanded),
          child: const Icon(Icons.chat_bubble),
        ),
      );
    }

    final expanded = _mode == FamilyChatDockMode.expanded;
    return Positioned(
      right: 12,
      bottom: 12,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.card,
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: MediaQuery.sizeOf(context).width < 400
              ? MediaQuery.sizeOf(context).width - 24
              : 320,
          height: expanded ? 440 : 48,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderSoft),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.chat_bubble, size: 16, color: AppTheme.accentPink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Family chat',
                        style: AppTheme.body(
                          size: 12,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: expanded ? 'Minimize' : 'Expand',
                      onPressed: () => _setMode(
                        expanded
                            ? FamilyChatDockMode.minimized
                            : FamilyChatDockMode.expanded,
                      ),
                      icon: Icon(
                        expanded
                            ? Icons.horizontal_rule
                            : Icons.open_in_full,
                        size: 16,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () {
                        _chatKey.currentState?.closeThread();
                        _setMode(FamilyChatDockMode.closed);
                      },
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
              if (expanded)
                Expanded(
                  child: FamilyChatPanel(
                    key: _chatKey,
                    familyId: widget.familyId,
                    initialPeerUserId: widget.initialPeerUserId,
                    compact: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
