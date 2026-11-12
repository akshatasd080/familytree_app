class FamilySummary {
  const FamilySummary({
    required this.id,
    required this.name,
    this.avatar,
    this.isActive = true,
    this.relationship,
    this.role,
  });

  final String id;
  final String name;
  final String? avatar;
  final bool isActive;
  final String? relationship;
  final String? role;

  factory FamilySummary.fromJson(Map<String, dynamic> json) {
    final family = json['family'] is Map
        ? Map<String, dynamic>.from(json['family'] as Map)
        : json;
    return FamilySummary(
      id: (family['id'] ?? json['familyId'] ?? '').toString(),
      name: (family['name'] ?? json['familyName'] ?? 'Family').toString(),
      avatar: (family['avatar'] ?? json['avatar'])?.toString(),
      isActive: family['is_active'] != false && family['isActive'] != false,
      relationship: (json['relationship'] ?? family['relationship'])?.toString(),
      role: (json['role'] ?? family['role'])?.toString(),
    );
  }
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    this.userId,
    this.relationship,
    this.status,
    this.email,
    this.phone,
    this.avatar,
    this.gender,
    this.profileInfo = const {},
  });

  final String id;
  final String name;
  final String? userId;
  final String? relationship;
  final String? status;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? gender;
  final Map<String, dynamic> profileInfo;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    final profile = json['profile_info'] ?? json['profileInfo'] ?? {};
    final profileMap = profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};
    return FamilyMember(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ??
              user['name'] ??
              profileMap['name'] ??
              'Member')
          .toString(),
      userId: (json['user_id'] ?? json['userId'] ?? user['id'])?.toString(),
      relationship: (json['relationship'])?.toString(),
      status: (json['status'] ?? json['membershipStatus'])?.toString(),
      email: (json['email'] ?? user['email'] ?? profileMap['email'])?.toString(),
      phone: (json['phone'] ?? user['phone'] ?? profileMap['phone'])?.toString(),
      avatar: (json['avatar'] ??
              profileMap['avatar'] ??
              user['avatar'])
          ?.toString(),
      gender: (json['gender'] ?? profileMap['gender'])?.toString(),
      profileInfo: profileMap,
    );
  }
}

class FamilyTreeData {
  const FamilyTreeData({
    required this.members,
    required this.relationships,
    this.role,
  });

  final List<FamilyMember> members;
  final List<Map<String, dynamic>> relationships;
  final String? role;

  factory FamilyTreeData.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'] is List ? json['members'] as List : [];
    final relsRaw =
        json['relationships'] is List ? json['relationships'] as List : [];
    return FamilyTreeData(
      members: membersRaw
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      relationships: relsRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      role: json['role']?.toString() ?? json['graphRole']?.toString(),
    );
  }
}
