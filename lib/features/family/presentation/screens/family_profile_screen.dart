import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';

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
  String? _avatar;
  final List<_PairFields> _educations = [];
  final List<_PairFields> _jobs = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

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
    for (final e in _educations) {
      e.dispose();
    }
    for (final j in _jobs) {
      j.dispose();
    }
    super.dispose();
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
      _avatar = (profile['avatar'] ?? data['avatar'])?.toString();

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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (name.length < 2) {
      setState(() => _error = 'Enter a valid name.');
      return;
    }
    if (phone.isNotEmpty && !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
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
      });
      if (!mounted) return;
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
    final url = mediaUrl(_avatar);
    return FtPage(
      title: 'Profile',
      actions: [
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveBody(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                      ),
                      border: Border.all(color: const Color(0xFFD1FAE5)),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor:
                                  AppTheme.forest.withValues(alpha: 0.12),
                              backgroundImage:
                                  url != null ? NetworkImage(url) : null,
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
                                      color: Colors.white,
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
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'City, State',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Date of birth',
                          value: _dob,
                          onTap: () => _pickDate(marriage: false),
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
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save profile'),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
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
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTheme.body(weight: FontWeight.w800)),
          ),
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
