/// Matches backend `utils/profilePrivacy.js` + web tree profile gating.
const kPrivacyKeys = [
  'dateOfBirth',
  'education',
  'job',
  'bloodGroup',
  'phone',
];

Map<String, String> normalizePrivacy(dynamic raw) {
  final src = raw is Map ? Map<String, dynamic>.from(raw) : const {};
  final out = <String, String>{};
  for (final key in kPrivacyKeys) {
    final value = (src[key] ?? '').toString().toLowerCase();
    out[key] = value == 'public' ? 'public' : 'private';
  }
  return out;
}

Map<String, String> privacyOfMember({
  Map<String, dynamic>? profileInfo,
  Map<String, dynamic>? memberJson,
}) {
  final fromProfile = profileInfo?['privacy'];
  final fromTop = memberJson?['privacy'];
  if (fromProfile is Map) return normalizePrivacy(fromProfile);
  if (fromTop is Map) return normalizePrivacy(fromTop);
  return normalizePrivacy(const {});
}

bool canSeePrivateFields({
  required bool isAdmin,
  required bool isSelf,
}) =>
    isAdmin || isSelf;

bool isFieldPrivate(
  Map<String, String> privacy,
  String key, {
  required bool canSeePrivate,
}) {
  if (canSeePrivate) return false;
  return (privacy[key] ?? 'private') != 'public';
}

String privateOrEmptyLabel({
  required bool isPrivate,
  required String emptyLabel,
  String privateLabel = 'Private',
}) =>
    isPrivate ? privateLabel : emptyLabel;
