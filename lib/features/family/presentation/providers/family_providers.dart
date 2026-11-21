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

/// Unread important-message count for sidebar badge (web parity).
class FamilyNoticesUnreadProvider extends ChangeNotifier {
  FamilyNoticesUnreadProvider(this._api);

  final FamilyApiService _api;
  int unreadCount = 0;
  bool loading = false;

  Future<void> refresh() async {
    loading = true;
    try {
      final res = await _api.getFamilyNoticesUnreadCount();
      final data = res.data;
      if (data is Map && data['unreadCount'] != null) {
        unreadCount = int.tryParse(data['unreadCount'].toString()) ?? 0;
      } else {
        unreadCount = 0;
      }
    } catch (_) {
      // Keep last known count on transient errors.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearLocal() {
    unreadCount = 0;
    notifyListeners();
  }
}

/// Unread direct-chat count across my families (web sidebar mediaUnread parity).
class FamilyChatUnreadProvider extends ChangeNotifier {
  FamilyChatUnreadProvider(this._api);

  final FamilyApiService _api;
  int unreadCount = 0;
  bool loading = false;

  Future<void> refresh({List<FamilySummary>? families}) async {
    loading = true;
    try {
      var list = families;
      if (list == null || list.isEmpty) {
        final res = await _api.listMyFamilies();
        final data = res.data;
        List raw = const [];
        if (data is Map && data['families'] is List) {
          raw = data['families'] as List;
        } else if (data is List) {
          raw = data;
        }
        list = raw
            .whereType<Map>()
            .map((e) => FamilySummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (list.isEmpty) {
        unreadCount = 0;
      } else {
        final totals = await Future.wait(
          list.map((family) async {
            try {
              final res = await _api.listFamilyChatConversations(family.id);
              final data = res.data;
              final conversations = data is Map && data['conversations'] is List
                  ? data['conversations'] as List
                  : const [];
              var sum = 0;
              for (final c in conversations) {
                if (c is! Map) continue;
                final u = c['unread'];
                sum += u is int ? u : int.tryParse('$u') ?? 0;
              }
              return sum;
            } catch (_) {
              return 0;
            }
          }),
        );
        unreadCount = totals.fold<int>(0, (a, b) => a + b);
      }
    } catch (_) {
      // Keep last known count on transient errors.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearLocal() {
    unreadCount = 0;
    notifyListeners();
  }
}
