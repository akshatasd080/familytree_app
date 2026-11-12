import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';
import '../providers/family_providers.dart';

class FamilyMediaScreen extends StatefulWidget {
  const FamilyMediaScreen({super.key});

  @override
  State<FamilyMediaScreen> createState() => _FamilyMediaScreenState();
}

class _FamilyMediaScreenState extends State<FamilyMediaScreen> {
  List<Map<String, dynamic>> _media = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
          await context.read<FamilyApiService>().listFamilyMedia(familyId);
      final data = res.data;
      List list = const [];
      if (data is Map && data['media'] is List) {
        list = data['media'] as List;
      } else if (data is List) {
        list = data;
      }
      _media = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    try {
      await context.read<FamilyApiService>().uploadFamilyMedia(
            familyId,
            filePath: file.path,
          );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = context.gridCount(phone: 2, tablet: 3, wide: 4);
    return FtPage(
      title: 'Media',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _upload,
        backgroundColor: AppTheme.forest,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _media.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No photos yet')),
                          ],
                        )
                      : GridView.builder(
                          padding: context.pagePadding.copyWith(bottom: 88),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: _media.length,
                          itemBuilder: (_, i) {
                            final item = _media[i];
                            final url = mediaUrl(
                              (item['url'] ??
                                      item['image'] ??
                                      item['path'] ??
                                      item['file_path'])
                                  ?.toString(),
                            );
                            final id = (item['id'] ?? '').toString();
                            final familyId =
                                context.read<FamilySessionProvider>().familyId!;
                            return GestureDetector(
                              onTap: () async {
                                try {
                                  await context
                                      .read<FamilyApiService>()
                                      .likeFamilyMedia(familyId, id);
                                } catch (_) {}
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: url == null
                                    ? Container(
                                        color: Colors.black12,
                                        child: const Icon(Icons.image),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: url,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
