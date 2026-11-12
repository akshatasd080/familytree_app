import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

/// Full port of tree_frontend `src/api/family.js`.
class FamilyApiService {
  FamilyApiService(this._api);

  final ApiClient _api;

  // --- family-auth ---
  Future<Response> registerFamily(Map<String, dynamic> payload) =>
      _api.post('/family-auth/register', data: payload);

  Future<Response> verifyFamilyOtp(Map<String, dynamic> payload) =>
      _api.post('/family-auth/verify-otp', data: payload);

  Future<Response> resendFamilyOtp(Map<String, dynamic> payload) =>
      _api.post('/family-auth/resend-otp', data: payload);

  // --- families ---
  Future<Response> getFamilyOverview() => _api.get('/families/overview');

  Future<Response> listAllFamilies() => _api.get('/families/admin');

  Future<Response> setFamilyStatus(String familyId, bool isActive) =>
      _api.patch('/families/$familyId/status', data: {'isActive': isActive});

  Future<Response> listMyFamilies() => _api.get('/families/mine');

  Future<Response> getFamilySettings(String familyId) =>
      _api.get('/families/$familyId/settings');

  Future<Response> updateFamilySettings(
    String familyId,
    Map<String, dynamic> payload,
  ) =>
      _api.put('/families/$familyId/settings', data: payload);

  Future<Response> uploadFamilyAvatar(String familyId, String filePath) {
    final form = FormData.fromMap({
      'avatar': MultipartFile.fromFileSync(filePath),
    });
    return _api.post(
      '/families/$familyId/settings/avatar',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> listFamilyMembers(String familyId) =>
      _api.get('/families/$familyId/members');

  Future<Response> checkMemberEmail(String familyId, String email) =>
      _api.post('/families/$familyId/members/check-email', data: {'email': email});

  Future<Response> checkMemberPhone(String familyId, String phone) =>
      _api.post('/families/$familyId/members/check-phone', data: {'phone': phone});

  Future<Response> inviteFamilyMember(
    String familyId,
    Map<String, dynamic> payload,
  ) =>
      _api.post('/families/$familyId/members/invite', data: payload);

  Future<Response> addFamilyMemberWithOtp(
    String familyId,
    Map<String, dynamic> payload,
  ) =>
      _api.post('/families/$familyId/members/add-with-otp', data: payload);

  Future<Response> uploadFamilyMemberPhoto(String familyId, String filePath) {
    final form = FormData.fromMap({
      'avatar': MultipartFile.fromFileSync(filePath),
    });
    return _api.post(
      '/families/$familyId/members/photo',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> updateFamilyMember(
    String familyId,
    String memberId,
    Map<String, dynamic> payload,
  ) =>
      _api.put('/families/$familyId/members/$memberId', data: payload);

  Future<Response> removeFamilyMember(String familyId, String memberId) =>
      _api.delete('/families/$familyId/members/$memberId');

  Future<Response> linkFamilyRelationship(
    String familyId,
    Map<String, dynamic> payload,
  ) =>
      _api.post('/families/$familyId/relationships', data: payload);

  Future<Response> getFamilyTree(
    String familyId, {
    Map<String, dynamic>? params,
  }) =>
      _api.get('/families/$familyId/tree', queryParameters: params);

  Future<Response> searchFamilyMembers(String familyId, String q) =>
      _api.get('/families/$familyId/members/search', queryParameters: {'q': q});

  // invitations
  Future<Response> lookupInvitation(String email) =>
      _api.get('/families/invitations/lookup', queryParameters: {'email': email});

  Future<Response> verifyInviteOtp(
    String invitationId,
    Map<String, dynamic> payload,
  ) =>
      _api.post('/families/invitations/$invitationId/verify-otp', data: payload);

  Future<Response> resendInviteOtp(String invitationId) =>
      _api.post('/families/invitations/$invitationId/resend-otp');

  Future<Response> cancelInvitation(String invitationId) =>
      _api.post('/families/invitations/$invitationId/cancel');

  Future<Response> listMyInvitations() => _api.get('/families/invitations/mine');

  Future<Response> acceptInvitation(String invitationId) =>
      _api.post('/families/invitations/$invitationId/accept');

  Future<Response> rejectInvitation(String invitationId) =>
      _api.post('/families/invitations/$invitationId/reject');

  Future<Response> listNotifications() => _api.get('/notifications');

  Future<Response> markNotificationRead(String id) =>
      _api.post('/notifications/$id/read');

  Future<Response> getMyFamilyProfile() => _api.get('/families/profile/me');

  Future<Response> updateMyFamilyProfile(Map<String, dynamic> payload) =>
      _api.put('/families/profile/me', data: payload);

  Future<Response> uploadMyFamilyAvatar(String filePath) {
    final form = FormData.fromMap({
      'avatar': MultipartFile.fromFileSync(filePath),
    });
    return _api.post(
      '/families/profile/avatar',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> listFamilyMedia(
    String familyId, {
    Map<String, dynamic>? params,
  }) =>
      _api.get('/families/$familyId/media', queryParameters: params);

  Future<Response> uploadFamilyMedia(
    String familyId, {
    required String filePath,
    String? caption,
  }) {
    final form = FormData.fromMap({
      'image': MultipartFile.fromFileSync(filePath),
      if (caption != null) 'caption': caption,
    });
    return _api.post(
      '/families/$familyId/media',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> commentFamilyMedia(
    String familyId,
    String mediaId,
    String body,
  ) =>
      _api.post(
        '/families/$familyId/media/$mediaId/comments',
        data: {'body': body},
      );

  Future<Response> likeFamilyMedia(String familyId, String mediaId) =>
      _api.post('/families/$familyId/media/$mediaId/like');

  Future<Response> deleteFamilyMedia(String familyId, String mediaId) =>
      _api.delete('/families/$familyId/media/$mediaId');

  Future<Response> listFamilyEvents(String familyId) =>
      _api.get('/families/$familyId/events');

  Future<Response> createFamilyEvent(
    String familyId,
    Map<String, dynamic> payload,
  ) =>
      _api.post('/families/$familyId/events', data: payload);

  Future<Response> updateFamilyEvent(
    String familyId,
    String eventId,
    Map<String, dynamic> payload,
  ) =>
      _api.put('/families/$familyId/events/$eventId', data: payload);

  Future<Response> deleteFamilyEvent(String familyId, String eventId) =>
      _api.delete('/families/$familyId/events/$eventId');

  Future<Response> listFamilyChatConversations(String familyId) =>
      _api.get('/families/$familyId/chat/conversations');

  Future<Response> listFamilyChatMessages(String familyId, String peerUserId) =>
      _api.get('/families/$familyId/chat/$peerUserId/messages');

  Future<Response> sendFamilyChatMessage(
    String familyId,
    String peerUserId,
    String body,
  ) =>
      _api.post(
        '/families/$familyId/chat/$peerUserId/messages',
        data: {'body': body},
      );

  Future<Response> listFamilyRooms(String familyId) =>
      _api.get('/families/$familyId/rooms');

  Future<Response> createFamilyRoom(
    String familyId,
    Map<String, dynamic> payload,
  ) =>
      _api.post('/families/$familyId/rooms', data: payload);

  Future<Response> inviteFamilyRoomMembers(
    String familyId,
    String roomId,
    List userIds,
  ) =>
      _api.post(
        '/families/$familyId/rooms/$roomId/invites',
        data: {'userIds': userIds},
      );

  Future<Response> respondFamilyRoomInvite(
    String familyId,
    String roomId,
    bool accept,
  ) =>
      _api.post(
        '/families/$familyId/rooms/$roomId/respond',
        data: {'accept': accept},
      );

  Future<Response> leaveFamilyRoom(String familyId, String roomId) =>
      _api.post('/families/$familyId/rooms/$roomId/leave');

  Future<Response> listFamilyRoomMessages(String familyId, String roomId) =>
      _api.get('/families/$familyId/rooms/$roomId/messages');

  Future<Response> sendFamilyRoomMessage(
    String familyId,
    String roomId,
    String body,
  ) =>
      _api.post(
        '/families/$familyId/rooms/$roomId/messages',
        data: {'body': body},
      );

  Future<Response> sendFamilyLogin(String email) =>
      _api.post('/families/send-login', data: {'email': email});

  Future<Response> requestPasswordOtp(Map<String, dynamic> payload) =>
      _api.post('/families/otp-password/request', data: payload);

  Future<Response> resetPasswordWithOtp(Map<String, dynamic> payload) =>
      _api.post('/families/otp-password/reset', data: payload);

  Future<Response> searchLinkFamilies(String familyId, String q) =>
      _api.get('/families/$familyId/link-search', queryParameters: {'q': q});

  Future<Response> listFamilyLinkRequests(String familyId) =>
      _api.get('/families/$familyId/link-requests');

  Future<Response> createFamilyLinkRequest(
    String familyId,
    Map<String, dynamic> payload,
  ) =>
      _api.post('/families/$familyId/link-requests', data: payload);

  Future<Response> acceptFamilyLinkRequest(String familyId, String requestId) =>
      _api.post('/families/$familyId/link-requests/$requestId/accept');

  Future<Response> declineFamilyLinkRequest(String familyId, String requestId) =>
      _api.post('/families/$familyId/link-requests/$requestId/decline');

  Future<Response> cancelFamilyLinkRequest(String familyId, String requestId) =>
      _api.post('/families/$familyId/link-requests/$requestId/cancel');

  Future<Response> lookupFamilyMembership(Map<String, dynamic> payload) =>
      _api.post('/families/lookup-membership', data: payload);

  Future<Response> searchFamilies(String q) =>
      _api.get('/families/search', queryParameters: {'q': q});

  Future<Response> createFamilyJoinRequest({
    required Map<String, dynamic> fields,
    String? photoPath,
  }) {
    if (photoPath != null) {
      final form = FormData.fromMap({
        ...fields,
        'photo': MultipartFile.fromFileSync(photoPath),
      });
      return _api.post(
        '/families/join-requests',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
    }
    return _api.post('/families/join-requests', data: fields);
  }

  Future<Response> listFamilyJoinRequests(
    String familyId, {
    String status = 'PENDING',
  }) =>
      _api.get(
        '/families/$familyId/join-requests',
        queryParameters: {'status': status},
      );

  Future<Response> approveFamilyJoinRequest(
    String familyId,
    String requestId,
  ) =>
      _api.post('/families/$familyId/join-requests/$requestId/approve');

  Future<Response> rejectFamilyJoinRequest(
    String familyId,
    String requestId,
  ) =>
      _api.post('/families/$familyId/join-requests/$requestId/reject');
}
