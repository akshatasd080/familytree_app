class FamilySummary {
  const FamilySummary({
    required this.id,
    required this.name,
    this.avatar,
    this.isActive = true,
    this.relationship,
    this.role,
    this.isAdmin = false,
    this.isCreator = false,
  });

  final String id;
  final String name;
  final String? avatar;
  final bool isActive;
  final String? relationship;
  final String? role;
  final bool isAdmin;
  final bool isCreator;

  factory FamilySummary.fromJson(Map<String, dynamic> json) {
    final family = json['family'] is Map
        ? Map<String, dynamic>.from(json['family'] as Map)
        : json;
    final rel =
        (json['relationship'] ?? family['relationship'])?.toString() ?? '';
    final isSiteCreator =
        rel.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '') == 'sitecreator';
    return FamilySummary(
      id: (family['id'] ?? json['familyId'] ?? '').toString(),
      name: (family['name'] ?? json['familyName'] ?? 'Family').toString(),
      avatar: (family['avatar'] ?? json['avatar'])?.toString(),
      isActive: family['is_active'] != false && family['isActive'] != false,
      relationship: rel.isEmpty ? null : rel,
      role: (json['role'] ?? family['role'])?.toString(),
      isAdmin: json['isAdmin'] == true ||
          family['isAdmin'] == true ||
          isSiteCreator,
      isCreator: json['isCreator'] == true ||
          family['isCreator'] == true ||
          isSiteCreator,
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
    this.location,
    this.emailStatus,
    this.joinedAt,
    this.isAlive = true,
    this.isAdmin = false,
    this.isOwner = false,
    this.invitePending = false,
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
  final String? location;
  final String? emailStatus;
  final String? joinedAt;
  final bool isAlive;
  final bool isAdmin;
  final bool isOwner;
  final bool invitePending;
  final Map<String, dynamic> profileInfo;

  bool get isSiteCreator =>
      isOwner ||
      (relationship ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '') ==
          'sitecreator';

  bool get isMembershipActive {
    final s = (status ?? 'ACTIVE').toUpperCase();
    return s != 'INACTIVE';
  }

  bool get hasLoginAccount => (userId ?? '').trim().isNotEmpty;

  String get displayEmail {
    final e = (email ?? '').trim();
    if (e.isEmpty || e.endsWith('@phone.familytree.local')) return '';
    return e;
  }

  FamilyMember copyWith({
    bool? isAdmin,
    bool? isOwner,
    bool? isAlive,
    String? status,
    bool? invitePending,
    Map<String, dynamic>? profileInfo,
  }) =>
      FamilyMember(
        id: id,
        name: name,
        userId: userId,
        relationship: relationship,
        status: status ?? this.status,
        email: email,
        phone: phone,
        avatar: avatar,
        gender: gender,
        location: location,
        emailStatus: emailStatus,
        joinedAt: joinedAt,
        isAlive: isAlive ?? this.isAlive,
        isAdmin: isAdmin ?? this.isAdmin,
        isOwner: isOwner ?? this.isOwner,
        invitePending: invitePending ?? this.invitePending,
        profileInfo: profileInfo ?? this.profileInfo,
      );

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    final profile = json['profile_info'] ?? json['profileInfo'] ?? {};
    final profileMap = profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};
    // Tree graph may expose privacy at top-level; keep it on profileInfo.
    if (profileMap['privacy'] == null && json['privacy'] is Map) {
      profileMap['privacy'] = Map<String, dynamic>.from(json['privacy'] as Map);
    }
    final aliveRaw = json['is_alive'] ?? json['isAlive'] ?? profileMap['isAlive'];
    final accessRole = (profileMap['accessRole'] ?? profileMap['role'] ?? '')
        .toString()
        .toLowerCase();
    final ownerFlag = json['isOwner'] == true ||
        json['is_owner'] == true ||
        (json['relationship'] ?? '')
                .toString()
                .toLowerCase()
                .replaceAll(RegExp(r'[\s_-]+'), '') ==
            'sitecreator';
    final adminFlag = json['isAdmin'] == true ||
        json['is_admin'] == true ||
        ownerFlag ||
        accessRole == 'admin';
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
      phone: (json['phone'] ??
              user['phone'] ??
              profileMap['phone'] ??
              profileMap['contactNumber'])
          ?.toString(),
      avatar: (json['avatar'] ??
              profileMap['avatar'] ??
              user['avatar'])
          ?.toString(),
      gender: (json['gender'] ?? profileMap['gender'])?.toString(),
      location: (json['location'] ?? profileMap['location'])?.toString(),
      emailStatus:
          (json['emailStatus'] ?? json['email_status'] ?? profileMap['emailStatus'])
              ?.toString(),
      joinedAt: (json['joinedAt'] ??
              json['joined_at'] ??
              json['createdAt'] ??
              json['created_at'])
          ?.toString(),
      isAlive: aliveRaw != false,
      isAdmin: adminFlag,
      isOwner: ownerFlag,
      invitePending: json['invitePending'] == true ||
          json['invite_pending'] == true ||
          (json['emailStatus'] ?? '').toString().toUpperCase() == 'PENDING',
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
