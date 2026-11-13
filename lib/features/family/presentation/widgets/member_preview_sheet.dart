import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';

const _relationshipChoices = <String>[
  'Father',
  'Mother',
  'Son',
  'Daughter',
  'Brother',
  'Sister',
  'Husband',
  'Wife',
  'Spouse',
  'Grandfather',
  'Grandmother',
  'Uncle',
  'Aunt',
  'Nephew',
  'Niece',
  'Cousin',
  'Relative',
];

Future<void> showMemberPreviewSheet({
  required BuildContext context,
  required FamilyMember member,
  required String familyId,
  required Future<void> Function() onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MemberPreviewSheet(
      member: member,
      familyId: familyId,
      onChanged: onChanged,
    ),
  );
}

class _MemberPreviewSheet extends StatelessWidget {
  const _MemberPreviewSheet({
    required this.member,
    required this.familyId,
    required this.onChanged,
  });

  final FamilyMember member;
  final String familyId;
  final Future<void> Function() onChanged;

  String _joinedLabel() {
    final raw = member.joinedAt;
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('MMM d, y · h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl(member.avatar);
    final phone = (member.phone ?? member.profileInfo['phone'] ?? '')
        .toString()
        .trim();
    final email = member.displayEmail;
    final location = (member.location ?? '').trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Member Preview',
                          style: AppTheme.display(size: 20),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFECFDF5), Color(0xFFF8FAFC)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFD1FAE5)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor:
                                    AppTheme.forest.withValues(alpha: 0.12),
                                backgroundImage:
                                    url != null ? NetworkImage(url) : null,
                                child: url == null
                                    ? Text(
                                        member.name.isNotEmpty
                                            ? member.name[0].toUpperCase()
                                            : '?',
                                        style: AppTheme.display(
                                          size: 22,
                                          color: AppTheme.forest,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.display(
                                        size: 20,
                                        color: member.isAlive
                                            ? AppTheme.ink
                                            : const Color(0xFFB91C1C),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      member.relationship ?? 'Family',
                                      style: AppTheme.body(
                                        size: 13,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _Chip(
                                          label: (member.status ?? 'ACTIVE')
                                              .toUpperCase(),
                                          color: const Color(0xFF059669),
                                          bg: const Color(0xFFD1FAE5),
                                        ),
                                        _Chip(
                                          label: member.isAlive
                                              ? 'Alive'
                                              : 'Memorial',
                                          color: member.isAlive
                                              ? const Color(0xFF0369A1)
                                              : const Color(0xFFBE123C),
                                          bg: member.isAlive
                                              ? const Color(0xFFE0F2FE)
                                              : const Color(0xFFFFE4E6),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _InfoTile(
                          icon: Icons.place_outlined,
                          label: 'Location',
                          value: location.isEmpty ? '—' : location,
                        ),
                        _InfoTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: phone.isEmpty ? '—' : phone,
                        ),
                        _InfoTile(
                          icon: Icons.mail_outline,
                          label: 'Email',
                          value: email.isEmpty ? '—' : email,
                        ),
                        _InfoTile(
                          icon: Icons.verified_outlined,
                          label: 'Email status',
                          value: member.emailStatus?.isNotEmpty == true
                              ? member.emailStatus!
                              : (email.isEmpty ? '—' : 'Unverified'),
                        ),
                        _InfoTile(
                          icon: Icons.badge_outlined,
                          label: 'Status',
                          value: member.status ?? '—',
                        ),
                        _InfoTile(
                          icon: Icons.favorite_outline,
                          label: 'Alive',
                          value: member.isAlive ? 'Yes' : 'Memorial',
                        ),
                        _InfoTile(
                          icon: Icons.event_available_outlined,
                          label: 'Joined',
                          value: _joinedLabel(),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            final changed = await showMemberEditSheet(
                              context: context,
                              member: member,
                              familyId: familyId,
                            );
                            if (changed) await onChanged();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
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
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: last ? 0 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.forest),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.body(size: 11, color: AppTheme.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> showMemberEditSheet({
  required BuildContext context,
  required FamilyMember member,
  required String familyId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.canvas,
    showDragHandle: true,
    builder: (ctx) => _MemberEditSheet(member: member, familyId: familyId),
  );
  return result == true;
}

class _MemberEditSheet extends StatefulWidget {
  const _MemberEditSheet({
    required this.member,
    required this.familyId,
  });

  final FamilyMember member;
  final String familyId;

  @override
  State<_MemberEditSheet> createState() => _MemberEditSheetState();
}

class _MemberEditSheetState extends State<_MemberEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late String _relationship;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    final info = m.profileInfo;
    _name = TextEditingController(text: m.name);
    final phone = (m.phone ?? info['phone'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\D'), '');
    _phone = TextEditingController(
      text: phone.length > 10 ? phone.substring(phone.length - 10) : phone,
    );
    _location = TextEditingController(
      text: (m.location ?? info['location'] ?? '').toString(),
    );
    _notes = TextEditingController(text: (info['notes'] ?? '').toString());
    final rel = (m.relationship ?? '').trim();
    if (m.isSiteCreator) {
      _relationship = 'SiteCreator';
    } else if (_relationshipChoices.any((r) => r.toLowerCase() == rel.toLowerCase())) {
      _relationship = _relationshipChoices
          .firstWhere((r) => r.toLowerCase() == rel.toLowerCase());
    } else {
      _relationship = rel.isEmpty ? 'Relative' : rel;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter a valid name.');
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() => _error = 'Mobile number must be exactly 10 digits.');
      return;
    }
    if (!widget.member.isSiteCreator && _relationship.trim().isEmpty) {
      setState(() => _error = 'Select a relationship.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': phone,
        'location': _location.text.trim(),
        'notes': _notes.text.trim(),
      };
      if (!widget.member.isSiteCreator) {
        payload['relationship'] = _relationship;
      }
      await context.read<FamilyApiService>().updateFamilyMember(
            widget.familyId,
            widget.member.id,
            payload,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.member.displayEmail;
    final choices = [
      ..._relationshipChoices,
      if (_relationship.isNotEmpty &&
          !_relationshipChoices.contains(_relationship) &&
          _relationship != 'SiteCreator')
        _relationship,
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Family Member', style: AppTheme.display(size: 20)),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Member Name'),
            ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Member Email',
                helperText: 'Members can add their own email from My Profile.',
              ),
              child: Text(
                email.isEmpty ? 'No personal email yet' : email,
                style: AppTheme.body(
                  color: email.isEmpty ? AppTheme.muted : AppTheme.ink,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (widget.member.isSiteCreator)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  helperText: 'Family owner role is locked.',
                ),
                child: Text('SiteCreator', style: AppTheme.body()),
              )
            else
              DropdownButtonFormField<String>(
                value: choices.contains(_relationship) ? _relationship : null,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: [
                  for (final r in choices)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _relationship = v);
                },
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Phone',
                counterText: '${_phone.text.length}/10 digits',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppTheme.body(color: Colors.red, size: 13)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update Member'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
