/// India phone normalization — mirrors Login.jsx / authController.
String normalizeLoginIdentifier(String raw) {
  var loginId = raw.trim();
  var phone = loginId.replaceAll(RegExp(r'\D'), '');
  if (phone.length == 12 && phone.startsWith('91')) {
    phone = phone.substring(2);
  }
  if (phone.length == 11 && phone.startsWith('0')) {
    phone = phone.substring(1);
  }
  if (phone.length == 11 && RegExp(r'^[6-9]\d{9}').hasMatch(phone)) {
    phone = phone.substring(0, 10);
  }
  if (RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
    loginId = phone;
  }
  return loginId;
}

bool isValidIndianMobile(String phone) =>
    RegExp(r'^[6-9]\d{9}$').hasMatch(phone.replaceAll(RegExp(r'\D'), ''));
