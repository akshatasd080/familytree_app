import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';
import '../providers/family_providers.dart';

class FamilyAdminScreen extends StatefulWidget {
  const FamilyAdminScreen({super.key});

  @override
  State<FamilyAdminScreen> createState() => _FamilyAdminScreenState();
}

class _FamilyAdminScreenState extends State<FamilyAdminScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _hometown = TextEditingController();
  String? _avatar;
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
    _description.dispose();
    _hometown.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<FamilySessionProvider>();
    if (session.familyId == null) await session.loadMine();
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
          await context.read<FamilyApiService>().getFamilySettings(familyId);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final family = data['family'] is Map
          ? Map<String, dynamic>.from(data['family'] as Map)
          : data;
      _name.text = (family['name'] ?? '').toString();
      _description.text = (family['description'] ?? '').toString();
      _hometown.text = (family['hometown'] ?? '').toString();
      _avatar = family['avatar']?.toString();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    setState(() => _saving = true);
    try {
      await context.read<FamilyApiService>().updateFamilySettings(familyId, {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'hometown': _hometown.text.trim(),
      });
      await context.read<FamilySessionProvider>().loadMine();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family settings saved')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    try {
      await context
          .read<FamilyApiService>()
          .uploadFamilyAvatar(familyId, file.path);
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
      title: 'Family Admin',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveBody(
              child: ListView(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _uploadAvatar,
                    child: CircleAvatar(
                      radius: 44,
                      backgroundImage: url != null ? NetworkImage(url) : null,
                      child: url == null
                          ? const Icon(Icons.park, size: 40)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Family name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hometown,
                  decoration: const InputDecoration(labelText: 'Hometown'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
                const SizedBox(height: 24),
              ],
            ),
            ),
    );
  }
}
