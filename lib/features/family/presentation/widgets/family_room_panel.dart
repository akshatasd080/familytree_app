import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';

/// Family private rooms — list, create, invite, chat (web Media parity).
class FamilyRoomPanel extends StatefulWidget {
  const FamilyRoomPanel({
    super.key,
    required this.familyId,
    this.members = const [],
    this.myUserId,
  });

  final String familyId;
  final List<FamilyMember> members;
  final String? myUserId;

  @override
  State<FamilyRoomPanel> createState() => FamilyRoomPanelState();
}

class FamilyRoomPanelState extends State<FamilyRoomPanel> {
  List<Map<String, dynamic>> _rooms = const [];
  List<Map<String, dynamic>> _invites = const [];
  Map<String, dynamic>? _openRoom;
  List<Map<String, dynamic>> _roomMembers = const [];
  List<Map<String, dynamic>> _roomMessages = const [];
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _roomLoading = false;
  bool _sending = false;
  List<String> _invitePick = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadRooms());
  }

  @override
  void didUpdateWidget(covariant FamilyRoomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyId != widget.familyId) {
      closeRoom();
      loadRooms();
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> loadRooms() async {
    setState(() => _loading = true);
    try {
      final res =
          await context.read<FamilyApiService>().listFamilyRooms(widget.familyId);
      final data = res.data;
      List rooms = const [];
      List invites = const [];
      if (data is Map) {
        if (data['rooms'] is List) rooms = data['rooms'] as List;
        if (data['invites'] is List) invites = data['invites'] as List;
      }
      _rooms = rooms
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _invites = invites
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      _rooms = const [];
      _invites = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void closeRoom() {
    setState(() {
      _openRoom = null;
      _roomMembers = const [];
      _roomMessages = const [];
      _draft.clear();
      _invitePick = const [];
    });
  }

  Future<void> openRoom(String roomId) async {
    setState(() {
      _roomLoading = true;
      _openRoom = {'id': roomId, 'name': 'Room'};
      _invitePick = const [];
    });
    try {
      final res = await context
          .read<FamilyApiService>()
          .listFamilyRoomMessages(widget.familyId, roomId);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      _openRoom = data['room'] is Map
          ? Map<String, dynamic>.from(data['room'] as Map)
          : {'id': roomId, 'name': 'Room'};
      _roomMembers = (data['members'] is List ? data['members'] as List : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _roomMessages = (data['messages'] is List ? data['messages'] as List : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      closeRoom();
    } finally {
      if (mounted) setState(() => _roomLoading = false);
    }
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    final roomId = (_openRoom?['id'] ?? '').toString();
    if (body.isEmpty || roomId.isEmpty) return;
    setState(() => _sending = true);
    try {
      final res = await context
          .read<FamilyApiService>()
          .sendFamilyRoomMessage(widget.familyId, roomId, body);
      final data = res.data;
      Map<String, dynamic>? msg;
      if (data is Map && data['message'] is Map) {
        msg = Map<String, dynamic>.from(data['message'] as Map);
      }
      if (msg != null) {
        setState(() {
          _roomMessages = [..._roomMessages, msg!];
          _draft.clear();
        });
        _scrollToEnd();
      }
      loadRooms();
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

  List<FamilyMember> get _accountMembers => widget.members
      .where(
        (m) =>
            m.userId != null &&
            m.userId!.isNotEmpty &&
            m.isAlive &&
            m.userId != widget.myUserId,
      )
      .toList();

  Future<void> _createRoom() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var picked = <String>{};
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create room', style: AppTheme.display(size: 20)),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Room name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Invite members',
                  style: AppTheme.body(weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ..._accountMembers.map(
                  (m) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: picked.contains(m.userId),
                    title: Text(m.name),
                    subtitle: Text(m.relationship ?? ''),
                    onChanged: (v) {
                      setLocal(() {
                        final next = {...picked};
                        if (v == true) {
                          next.add(m.userId!);
                        } else {
                          next.remove(m.userId);
                        }
                        picked = next;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentPink,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (nameCtrl.text.trim().isEmpty) return;
    try {
      final res = await context.read<FamilyApiService>().createFamilyRoom(
            widget.familyId,
            {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'userIds': picked.toList(),
            },
          );
      await loadRooms();
      final roomId = res.data is Map
          ? (res.data['room'] is Map
              ? res.data['room']['id']?.toString()
              : res.data['id']?.toString())
          : null;
      if (roomId != null) openRoom(roomId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room created. People join after they accept.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _respondInvite(String roomId, bool accept) async {
    try {
      await context
          .read<FamilyApiService>()
          .respondFamilyRoomInvite(widget.familyId, roomId, accept);
      await loadRooms();
      if (accept) openRoom(roomId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'You joined the room' : 'Request declined'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _inviteMembers() async {
    final roomId = (_openRoom?['id'] ?? '').toString();
    if (roomId.isEmpty) return;
    final existing = _roomMembers
        .map((m) => (m['userId'] ?? m['user_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final candidates =
        _accountMembers.where((m) => !existing.contains(m.userId)).toList();
    var picked = <String>{..._invitePick};
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
              Text('Invite to room', style: AppTheme.display(size: 20)),
              const SizedBox(height: 8),
              if (candidates.isEmpty)
                Text(
                  'Everyone is already in this room.',
                  style: AppTheme.body(color: AppTheme.muted),
                )
              else
                ...candidates.map(
                  (m) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: picked.contains(m.userId),
                    title: Text(m.name),
                    onChanged: (v) {
                      setLocal(() {
                        final next = {...picked};
                        if (v == true) {
                          next.add(m.userId!);
                        } else {
                          next.remove(m.userId);
                        }
                        picked = next;
                      });
                    },
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: candidates.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Send invites'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || picked.isEmpty || !mounted) return;
    try {
      await context.read<FamilyApiService>().inviteFamilyRoomMembers(
            widget.familyId,
            roomId,
            picked.toList(),
          );
      setState(() => _invitePick = const []);
      await openRoom(roomId);
      loadRooms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _leaveRoom() async {
    final roomId = (_openRoom?['id'] ?? '').toString();
    if (roomId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this room?'),
        content: const Text('You will stop seeing its chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context
          .read<FamilyApiService>()
          .leaveFamilyRoom(widget.familyId, roomId);
      closeRoom();
      await loadRooms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_openRoom != null) return _buildRoomChat();
    return _buildList();
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Rooms',
                style: AppTheme.body(weight: FontWeight.w800),
              ),
            ),
            FilledButton.tonal(
              onPressed: _createRoom,
              child: const Text('Create'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_invites.isEmpty && _rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Create a room, name it, and add family. Only people you add can see it, and they join after they accept.',
              style: AppTheme.body(size: 12, color: AppTheme.muted),
            ),
          ),
        ..._invites.map((invite) {
          final id = (invite['id'] ?? '').toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.amber50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.amber200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite['name']?.toString() ?? 'Room invite',
                  style: AppTheme.body(weight: FontWeight.w800),
                ),
                Text(
                  '${invite['invitedByName'] ?? 'Someone'} invited you'
                  '${(invite['description'] ?? '').toString().isNotEmpty ? ' · ${invite['description']}' : ''}',
                  style: AppTheme.body(size: 11, color: AppTheme.muted),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _respondInvite(id, true),
                      child: const Text('Accept'),
                    ),
                    TextButton(
                      onPressed: () => _respondInvite(id, false),
                      child: const Text('Decline'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        ..._rooms.map((room) {
          final id = (room['id'] ?? '').toString();
          final last = room['lastMessage'] is Map
              ? (room['lastMessage']['body'] ?? '').toString()
              : (room['description'] ??
                      '${room['memberCount'] ?? ''} in this room')
                  .toString();
          final name = (room['name'] ?? 'Room').toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => openRoom(id),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEDE9FE),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'R',
                  style: const TextStyle(
                    color: Color(0xFF6D28D9),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(weight: FontWeight.w700),
                    ),
                  ),
                  if (room['isOwner'] == true) ...[
                    const SizedBox(width: 6),
                    Text(
                      'Owner',
                      style: AppTheme.body(
                        size: 10,
                        color: const Color(0xFF6D28D9),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.group_outlined, size: 18),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRoomChat() {
    final name = (_openRoom?['name'] ?? 'Room').toString();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: closeRoom,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(weight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Invite',
                onPressed: _inviteMembers,
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
              IconButton(
                tooltip: 'Leave',
                onPressed: _leaveRoom,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _roomLoading
              ? const Center(child: CircularProgressIndicator())
              : _roomMessages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet',
                        style: AppTheme.body(size: 12, color: AppTheme.muted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _roomMessages.length,
                      itemBuilder: (_, i) {
                        final m = _roomMessages[i];
                        final fromMe = m['fromMe'] == true ||
                            m['from_me'] == true ||
                            (widget.myUserId != null &&
                                (m['senderId'] ?? m['userId'] ?? '')
                                        .toString() ==
                                    widget.myUserId);
                        final body =
                            (m['body'] ?? m['message'] ?? '').toString();
                        final sender =
                            (m['senderName'] ?? m['name'] ?? '').toString();
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
                                  MediaQuery.sizeOf(context).width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: fromMe
                                  ? AppTheme.accentPink
                                  : AppTheme.card,
                              borderRadius: BorderRadius.circular(14),
                              border: fromMe
                                  ? null
                                  : Border.all(color: AppTheme.borderSoft),
                            ),
                            child: Column(
                              crossAxisAlignment: fromMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!fromMe && sender.isNotEmpty)
                                  Text(
                                    sender,
                                    style: AppTheme.body(
                                      size: 10,
                                      weight: FontWeight.w700,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                Text(
                                  body,
                                  style: AppTheme.body(
                                    size: 12,
                                    color:
                                        fromMe ? Colors.white : AppTheme.ink,
                                  ),
                                ),
                              ],
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
                    hintText: 'Message room…',
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
              const SizedBox(width: 6),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentPink,
                  foregroundColor: Colors.white,
                ),
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
