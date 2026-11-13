import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../../domain/ego_tree.dart';

const relationshipOptions = <(String, String)>[
  ('Father', 'male'),
  ('Mother', 'female'),
  ('Son', 'male'),
  ('Daughter', 'female'),
  ('Brother', 'male'),
  ('Sister', 'female'),
  ('Husband', 'male'),
  ('Wife', 'female'),
  ('Spouse', ''),
  ('Grandfather', 'male'),
  ('Grandmother', 'female'),
  ('Grandson', 'male'),
  ('Granddaughter', 'female'),
  ('Uncle', 'male'),
  ('Aunt', 'female'),
  ('Nephew', 'male'),
  ('Niece', 'female'),
  ('Cousin', ''),
  ('Father-in-law', 'male'),
  ('Mother-in-law', 'female'),
  ('Brother-in-law', 'male'),
  ('Sister-in-law', 'female'),
];

/// Web-parity Add relative form (add-with-otp / link existing).
Future<bool> showAddRelativeSheet({
  required BuildContext context,
  required String familyId,
  required List<FamilyMember> members,
  required FamilyMember relatedTo,
  required String relationship,
  required String gender,
  String? focusUserId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.canvas,
    builder: (ctx) => _AddRelativeSheet(
      familyId: familyId,
      members: members,
      initialRelatedTo: relatedTo,
      initialRelationship: relationship,
      initialGender: gender,
      focusUserId: focusUserId,
    ),
  );
  return result == true;
}

Future<bool> showSetRelationSheet({
  required BuildContext context,
  required String familyId,
  required List<FamilyMember> members,
  required FamilyMember member,
  FamilyMember? initialTarget,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.canvas,
    builder: (ctx) => _SetRelationSheet(
      familyId: familyId,
      members: members,
      member: member,
      initialTarget: initialTarget,
    ),
  );
  return result == true;
}

class _AddRelativeSheet extends StatefulWidget {
  const _AddRelativeSheet({
    required this.familyId,
    required this.members,
    required this.initialRelatedTo,
    required this.initialRelationship,
    required this.initialGender,
    this.focusUserId,
  });

  final String familyId;
  final List<FamilyMember> members;
  final FamilyMember initialRelatedTo;
  final String initialRelationship;
  final String initialGender;
  final String? focusUserId;

  @override
  State<_AddRelativeSheet> createState() => _AddRelativeSheetState();
}

class _AddRelativeSheetState extends State<_AddRelativeSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late final TextEditingController _memberQuery;
  late String _relationship;
  late String _gender;
  late FamilyMember _relatedTo;
  String _dob = '';
  bool _isAlive = true;
  String? _existingMemberId;
  String? _photoPath;
  String? _phoneHint;
  bool _phoneBlocked = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _notes = TextEditingController();
    _memberQuery = TextEditingController();
    _relationship = widget.initialRelationship;
    _gender = widget.initialGender;
    _relatedTo = widget.initialRelatedTo;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    _memberQuery.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _checkPhone() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() {
        _phoneBlocked = true;
        _phoneHint = 'Enter a valid 10-digit mobile number';
      });
      return;
    }
    try {
      final res = await context
          .read<FamilyApiService>()
          .checkMemberPhone(widget.familyId, phone);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final already = data['alreadyMember'] == true;
      final pending = data['pendingInvitation'] == true;
      final msg = data['message']?.toString();
      setState(() {
        _phoneBlocked = already || pending;
        _phoneHint = msg ??
            (already
                ? 'Already a family member'
                : pending
                    ? 'Invitation already pending'
                    : '');
      });
    } catch (_) {}
  }

  Future<String?> _uploadAvatar() async {
    if (_photoPath == null) return null;
    final res = await context
        .read<FamilyApiService>()
        .uploadFamilyMemberPhoto(widget.familyId, _photoPath!);
    final data = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
    return data['avatar']?.toString();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _submitting = true;
    });
    final api = context.read<FamilyApiService>();
    final anchorId = _relatedTo.id.isNotEmpty
        ? _relatedTo.id
        : (_relatedTo.userId ?? '');
    if (anchorId.isEmpty) {
      setState(() {
        _error = 'Choose who this person is related to.';
        _submitting = false;
      });
      return;
    }

    try {
      if (!_isAlive) {
        if (_name.text.trim().isEmpty) {
          setState(() {
            _error = 'Enter the name.';
            _submitting = false;
          });
          return;
        }
        final avatar = await _uploadAvatar();
        await api.addFamilyMemberWithOtp(widget.familyId, {
          'name': _name.text.trim(),
          'relationship': _relationship,
          'isAlive': false,
          'profileInfo': {
            'isAlive': false,
            if (_gender.isNotEmpty) 'gender': _gender,
            if (_dob.isNotEmpty) 'dateOfBirth': _dob,
            if (avatar != null) 'avatar': avatar,
            if (avatar != null) 'profileImage': avatar,
            'relatedTo': anchorId,
            'linkType': linkTypeFromRelationship(_relationship),
            if (widget.focusUserId != null)
              'addedFromFocusUserId': widget.focusUserId,
          },
        });
      } else if (_existingMemberId != null) {
        await api.linkFamilyRelationship(widget.familyId, {
          'memberId': _existingMemberId,
          'relatedMemberId': anchorId,
          'relationshipType': _relationship,
        });
      } else {
        final phone = _phone.text.trim();
        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
          setState(() {
            _phoneBlocked = true;
            _phoneHint = 'Enter a valid 10-digit mobile number';
            _submitting = false;
          });
          return;
        }
        if (_phoneBlocked) {
          setState(() => _submitting = false);
          return;
        }
        if (_name.text.trim().isEmpty) {
          setState(() {
            _error = 'Enter the name.';
            _submitting = false;
          });
          return;
        }
        final avatar = await _uploadAvatar();
        await api.addFamilyMemberWithOtp(widget.familyId, {
          'name': _name.text.trim(),
          'phone': phone,
          if (_email.text.trim().isNotEmpty)
            'email': _email.text.trim().toLowerCase(),
          'relationship': _relationship,
          'profileInfo': {
            'phone': phone,
            if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
            if (_gender.isNotEmpty) 'gender': _gender,
            if (_dob.isNotEmpty) 'dateOfBirth': _dob,
            if (avatar != null) 'avatar': avatar,
            if (avatar != null) 'profileImage': avatar,
            'relatedTo': anchorId,
            'linkType': linkTypeFromRelationship(_relationship),
            if (widget.focusUserId != null)
              'addedFromFocusUserId': widget.focusUserId,
          },
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString();
      setState(() {
        if (RegExp(r'already|pending|mobile|phone', caseSensitive: false)
            .hasMatch(msg)) {
          _phoneBlocked = true;
          _phoneHint = msg;
        } else {
          _error = msg;
        }
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add $_relationship',
              style: AppTheme.display(size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              'New person will be ${_relatedTo.name}\'s $_relationship',
              style: AppTheme.body(size: 13, color: AppTheme.muted),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 88,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSoft),
                        ),
                        child: _photoPath == null
                            ? Center(
                                child: Text(
                                  'Photo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_photoPath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 88,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _pickPhoto,
                        child: const Text('Upload'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        children: [
                          for (final g in ['male', 'female', 'other'])
                            ChoiceChip(
                              label: Text(
                                g[0].toUpperCase() + g.substring(1),
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _gender == g,
                              onSelected: (_) => setState(() => _gender = g),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Member Name',
                        ),
                        onChanged: (_) {
                          if (_existingMemberId != null) {
                            setState(() => _existingMemberId = null);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of birth',
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime(now.year - 25),
                              firstDate: DateTime(1900),
                              lastDate: now,
                            );
                            if (picked != null) {
                              setState(() {
                                _dob =
                                    '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                              });
                            }
                          },
                          child: Text(
                            _dob.isEmpty ? 'Select date' : _dob,
                            style: AppTheme.body(
                              color: _dob.isEmpty
                                  ? AppTheme.muted
                                  : AppTheme.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Living'),
                            selected: _isAlive,
                            onSelected: (_) => setState(() {
                              _isAlive = true;
                            }),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Not alive'),
                            selected: !_isAlive,
                            onSelected: (_) => setState(() {
                              _isAlive = false;
                              _existingMemberId = null;
                              _phone.clear();
                              _email.clear();
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _relationship,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: [
                for (final opt in relationshipOptions)
                  DropdownMenuItem(value: opt.$1, child: Text(opt.$1)),
              ],
              onChanged: (v) {
                if (v == null) return;
                final match = relationshipOptions
                    .where((e) => e.$1 == v)
                    .cast<(String, String)?>()
                    .firstWhere((e) => true, orElse: () => null);
                setState(() {
                  _relationship = v;
                  if (match != null && match.$2.isNotEmpty) {
                    _gender = match.$2;
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _relatedTo.id,
              decoration: const InputDecoration(labelText: 'Related to'),
              items: [
                for (final m in widget.members)
                  DropdownMenuItem(value: m.id, child: Text(m.name)),
              ],
              onChanged: (id) {
                final person = widget.members
                    .where((m) => m.id == id)
                    .cast<FamilyMember?>()
                    .firstWhere((e) => true, orElse: () => null);
                if (person != null) setState(() => _relatedTo = person);
              },
            ),
            if (_isAlive) ...[
              const SizedBox(height: 12),
              Text(
                'Or link someone already in this family',
                style: AppTheme.body(size: 12, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _memberQuery,
                decoration: const InputDecoration(
                  hintText: 'Search existing name',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_memberQuery.text.trim().isNotEmpty)
                ...widget.members
                    .where(
                      (m) => m.name
                          .toLowerCase()
                          .contains(_memberQuery.text.trim().toLowerCase()),
                    )
                    .take(6)
                    .map(
                      (m) => ListTile(
                        dense: true,
                        title: Text('Use existing: ${m.name}'),
                        selected: _existingMemberId == m.id,
                        onTap: () => setState(() {
                          _existingMemberId = m.id;
                          _name.text = m.name;
                          if ((m.gender ?? '').isNotEmpty) {
                            _gender = m.gender!;
                          }
                        }),
                      ),
                    ),
              const SizedBox(height: 8),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'Mobile (+91)',
                  counterText: '',
                  errorText: _phoneHint?.isEmpty == true ? null : _phoneHint,
                ),
                onChanged: (_) {
                  if (_phoneBlocked || _phoneHint != null) {
                    setState(() {
                      _phoneBlocked = false;
                      _phoneHint = null;
                    });
                  }
                },
                onEditingComplete: _checkPhone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppTheme.body(color: Colors.red, size: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isAlive ? 'Save & send invite' : 'Save memorial'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRelationSheet extends StatefulWidget {
  const _SetRelationSheet({
    required this.familyId,
    required this.members,
    required this.member,
    this.initialTarget,
  });

  final String familyId;
  final List<FamilyMember> members;
  final FamilyMember member;
  final FamilyMember? initialTarget;

  @override
  State<_SetRelationSheet> createState() => _SetRelationSheetState();
}

class _SetRelationSheetState extends State<_SetRelationSheet> {
  FamilyMember? _target;
  String? _relationship;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget;
  }

  Future<void> _save([String? rel]) async {
    final relationship = rel ?? _relationship;
    final target = _target;
    if (target == null || relationship == null || relationship.isEmpty) {
      setState(() => _error = 'Pick related-to and a relationship.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _relationship = relationship;
    });
    try {
      await context.read<FamilyApiService>().linkFamilyRelationship(
        widget.familyId,
        {
          'memberId': widget.member.id,
          'relatedMemberId': target.id,
          'relationshipType': relationship,
        },
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
    final others = widget.members
        .where((m) => m.id != widget.member.id)
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set relation', style: AppTheme.display(size: 20)),
          const SizedBox(height: 4),
          Text(
            'Place ${widget.member.name} on the tree',
            style: AppTheme.body(size: 13, color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _target?.id,
            decoration: const InputDecoration(labelText: 'Related to'),
            items: [
              for (final m in others)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(
                    '${m.name}${m.relationship != null ? ' · ${m.relationship}' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              final person = others
                  .where((m) => m.id == id)
                  .cast<FamilyMember?>()
                  .firstWhere((e) => true, orElse: () => null);
              setState(() => _target = person);
            },
          ),
          const SizedBox(height: 12),
          Text(
            _target == null
                ? '${widget.member.name} is their:'
                : '${widget.member.name} is ${_target!.name}\'s:',
            style: AppTheme.body(size: 12, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final opt in relationshipOptions)
                    ChoiceChip(
                      label: Text(opt.$1, style: const TextStyle(fontSize: 12)),
                      selected: _relationship == opt.$1,
                      selectedColor: const Color(0xFFF97316),
                      labelStyle: TextStyle(
                        color: _relationship == opt.$1
                            ? Colors.white
                            : const Color(0xFF9A3412),
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: _target == null || _saving
                          ? null
                          : (_) => _save(opt.$1),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: AppTheme.body(color: Colors.red, size: 12)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save on tree'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
