import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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
  bool _allowed = true;
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

  bool _isAdminFamily(Map<String, dynamic>? family, FamilySessionProvider session) {
    final role = (family?['role'] ?? session.current?.role ?? '').toString().toLowerCase();
    if (role == 'admin' || role == 'creator' || role == 'owner') return true;
    final auth = context.read<AuthProvider>();
    final rel = (session.current?.relationship ?? '').toLowerCase().replaceAll(' ', '');
    if (rel == 'sitecreator') return true;
    return auth.hasPermission('family.update') ||
        auth.hasPermission('family.admin');
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
          await context.read<FamilyApiService>().getFamilySettings(familyId);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final family = data['family'] is Map
          ? Map<String, dynamic>.from(data['family'] as Map)
          : data;
      final allowed = _isAdminFamily(family, session);
      if (!allowed) {
        setState(() {
          _allowed = false;
          _loading = false;
        });
        if (mounted) context.openShell('/family/tree');
        return;
      }
      _name.text = (family['name'] ?? '').toString();
      _description.text = (family['description'] ?? '').toString();
      _hometown.text = (family['hometown'] ?? '').toString();
      _avatar = family['avatar']?.toString();
      setState(() => _allowed = true);
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

  Future<void> _uploadBanner() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
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
      actions: [
        TextButton(
          onPressed: _loading ? null : _load,
          child: const Text('Reset'),
        ),
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
      body: !_allowed
          ? const Center(child: Text('Admin access required'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ResponsiveBody(
                  child: ListView(
                    children: [
                      GestureDetector(
                        onTap: _uploadBanner,
                        child: AspectRatio(
                          aspectRatio: 21 / 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (url != null)
                                  Image.network(url, fit: BoxFit.cover)
                                else
                                  Container(
                                    color: const Color(0xFFECFDF5),
                                    child: Icon(
                                      Icons.park,
                                      size: 48,
                                      color: AppTheme.forest,
                                    ),
                                  ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.55),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 12,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _name.text.isEmpty
                                            ? 'Family name'
                                            : _name.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.display(
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (_hometown.text.trim().isNotEmpty)
                                        Text(
                                          _hometown.text.trim(),
                                          style: AppTheme.body(
                                            size: 12,
                                            color: Colors.white
                                                .withValues(alpha: 0.9),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Material(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(999),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        'Change banner',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap banner to upload a wide family photo (21:9).',
                        style: AppTheme.body(size: 12, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'Family name'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _hometown,
                        decoration:
                            const InputDecoration(labelText: 'Hometown'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _description,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
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
