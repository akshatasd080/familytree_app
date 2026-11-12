import 'package:flutter/foundation.dart';

import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';

class FamilySessionProvider extends ChangeNotifier {
  FamilySessionProvider(this._api);

  final FamilyApiService _api;

  List<FamilySummary> families = const [];
  FamilySummary? current;
  bool loading = false;
  String? error;

  String? get familyId => current?.id;

  Future<void> loadMine() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.listMyFamilies();
      final data = res.data;
      List list = const [];
      if (data is Map && data['families'] is List) {
        list = data['families'] as List;
      } else if (data is List) {
        list = data;
      }
      families = list
          .whereType<Map>()
          .map((e) => FamilySummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (families.isNotEmpty) {
        current ??= families.first;
        // keep current if still present
        final still = families.where((f) => f.id == current!.id);
        current = still.isNotEmpty ? still.first : families.first;
      } else {
        current = null;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectFamily(FamilySummary family) {
    current = family;
    notifyListeners();
  }
}
