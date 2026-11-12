import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/widgets/ft_widgets.dart';
import '../../../family/data/family_api_service.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _tab = 0; // 0 find, 1 signin
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _checkPhone = TextEditingController();
  final _checkEmail = TextEditingController();
  final _familyQuery = TextEditingController();
  bool _obscure = true;
  bool _signingIn = false;
  bool _lookupLoading = false;
  Map<String, dynamic>? _lookupResult;
  List<Map<String, dynamic>> _familyResults = [];
  String? _error;
  bool _inactive = false;

  final _otpPhone = TextEditingController();
  final _otpCode = TextEditingController();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _checkPhone.dispose();
    _checkEmail.dispose();
    _familyQuery.dispose();
    _otpPhone.dispose();
    _otpCode.dispose();
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
      _inactive = false;
    });
    try {
      await context.read<AuthProvider>().login(
            email: _email.text,
            password: _password.text,
          );
      if (mounted) context.go('/dashboard');
    } on ApiException catch (e) {
      setState(() {
        _inactive = e.isFamilyInactive;
        _error = e.message;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _lookup() async {
    setState(() {
      _lookupLoading = true;
      _lookupResult = null;
      _error = null;
    });
    try {
      final api = context.read<FamilyApiService>();
      final payload = _checkPhone.text.trim().isNotEmpty
          ? {'phone': normalizeLoginIdentifier(_checkPhone.text)}
          : {'email': _checkEmail.text.trim().toLowerCase()};
      final res = await api.lookupFamilyMembership(payload);
      final data = res.data;
      setState(() {
        _lookupResult = data is Map
            ? Map<String, dynamic>.from(data)
            : {'message': data?.toString()};
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _lookupLoading = false);
    }
  }

  Future<void> _searchFamilies() async {
    final q = _familyQuery.text.trim();
    if (q.isEmpty) return;
    try {
      final res = await context.read<FamilyApiService>().searchFamilies(q);
      final data = res.data;
      List list = const [];
      if (data is Map && data['families'] is List) {
        list = data['families'] as List;
      } else if (data is List) {
        list = data;
      }
      setState(() {
        _familyResults = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _joinFamily(Map<String, dynamic> family) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final message = TextEditingController();
    String? photoPath;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Join ${family['name'] ?? 'family'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                ),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: message,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await ImagePicker()
                        .pickImage(source: ImageSource.gallery);
                    if (file != null) setLocal(() => photoPath = file.path);
                  },
                  icon: const Icon(Icons.photo),
                  label:
                      Text(photoPath == null ? 'Add photo' : 'Photo selected'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<FamilyApiService>().createFamilyJoinRequest(
        fields: {
          'familyId': family['id'],
          'name': name.text.trim(),
          'email': email.text.trim(),
          'phone': phone.text.trim(),
          'message': message.text.trim(),
        },
        photoPath: photoPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openOtpPassword() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reset password with OTP', style: AppTheme.display(size: 20)),
              const SizedBox(height: 12),
              TextField(
                controller: _otpPhone,
                decoration:
                    const InputDecoration(labelText: 'Phone or email'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  try {
                    final id = normalizeLoginIdentifier(_otpPhone.text);
                    final payload = isValidIndianMobile(id)
                        ? {'phone': id}
                        : {'email': id};
                    await context
                        .read<FamilyApiService>()
                        .requestPasswordOtp(payload);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('OTP sent')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  }
                },
                child: const Text('Send OTP'),
              ),
              TextField(
                controller: _otpCode,
                decoration: const InputDecoration(labelText: 'OTP'),
              ),
              TextField(
                controller: _newPass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              TextField(
                controller: _confirmPass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  try {
                    final id = normalizeLoginIdentifier(_otpPhone.text);
                    await context.read<FamilyApiService>().resetPasswordWithOtp({
                      if (isValidIndianMobile(id)) 'phone': id else 'email': id,
                      'otp': _otpCode.text.trim(),
                      'newPassword': _newPass.text,
                      'confirmPassword': _confirmPass.text,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password updated')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  }
                },
                child: const Text('Reset password'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  const Spacer(),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.go('/'),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderSoft),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth > 520
                      ? 480.0
                      : constraints.maxWidth;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: maxW,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.cream,
                                borderRadius: BorderRadius.circular(24),
                                gradient: RadialGradient(
                                  center: const Alignment(0, -0.2),
                                  radius: 0.9,
                                  colors: [
                                    const Color(0xFF8DBA7A)
                                        .withValues(alpha: 0.35),
                                    AppTheme.cream,
                                  ],
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  'assets/images/family-tree-labeled.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(
                                      Icons.park,
                                      size: 64,
                                      color: AppTheme.forest,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_tab == 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.park,
                                    size: 14,
                                    color: AppTheme.forest,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Your roots, connected',
                                      style: AppTheme.body(
                                        size: 11,
                                        weight: FontWeight.w600,
                                        color: AppTheme.forest,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Every branch tells a story',
                              style: AppTheme.display(size: 28),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Already in a family? Sign in. New here? Check your email, then create a tree or request to join.',
                              style: AppTheme.body(
                                color: AppTheme.mutedSoft,
                                size: 13,
                              ),
                            ),
                          ] else ...[
                            FtSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New here?',
                                    style: AppTheme.body(weight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start your own family tree — only if you are not already in a family.',
                                    style: AppTheme.body(
                                      size: 12,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () =>
                                        context.go('/family/register'),
                                    icon: const Icon(Icons.park),
                                    label: const Text('Create your family'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const FtBrandMark(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Family Tree',
                                      style: AppTheme.display(size: 18),
                                    ),
                                    Text(
                                      'Heritage & connection',
                                      style: AppTheme.body(
                                        size: 11,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.tabTrack,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _TabBtn(
                                  label: 'Find my family',
                                  selected: _tab == 0,
                                  onTap: () => setState(() => _tab = 0),
                                ),
                                _TabBtn(
                                  label: 'Sign in',
                                  selected: _tab == 1,
                                  onTap: () => setState(() => _tab = 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_tab == 1) ..._signInBody() else ..._findBody(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _signInBody() {
    return [
      Text('Welcome back', style: AppTheme.display(size: 26)),
      const SizedBox(height: 6),
      Text(
        'Enter your details to continue to your family space.',
        style: AppTheme.body(color: AppTheme.mutedSoft, size: 13),
      ),
      const SizedBox(height: 14),
      if (_inactive)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.amber50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.amber200),
          ),
          child: Text(
            _error ??
                'Your family has been deactivated. Please contact WeFamily Admin.',
            style: AppTheme.body(size: 13, color: const Color(0xFF78350F)),
          ),
        ),
      if (_error != null && !_inactive) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE4E6)),
          ),
          child: Text(
            _error!,
            style: AppTheme.body(size: 13, color: const Color(0xFFBE123C)),
          ),
        ),
        const SizedBox(height: 10),
      ],
      Text('Email or mobile',
          style: AppTheme.body(size: 12, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: _email,
        decoration: const InputDecoration(
          hintText: 'you@email.com or 10-digit mobile',
        ),
      ),
      const SizedBox(height: 12),
      Text('Password',
          style: AppTheme.body(size: 12, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: _password,
        obscureText: _obscure,
        decoration: InputDecoration(
          hintText: 'Enter your password',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _openOtpPassword,
          child: Text(
            'Forgot password?',
            style: AppTheme.body(
              size: 13,
              weight: FontWeight.w600,
              color: AppTheme.forest,
            ),
          ),
        ),
      ),
      FilledButton(
        onPressed: _signingIn ? null : _signIn,
        child: _signingIn
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Sign in'),
      ),
    ];
  }

  List<Widget> _findBody() {
    return [
      Text('Find my family', style: AppTheme.display(size: 24)),
      const SizedBox(height: 6),
      Text(
        'Check if you already belong to a family, or search to join one.',
        style: AppTheme.body(color: AppTheme.mutedSoft, size: 13),
      ),
      const SizedBox(height: 14),
      if (_error != null)
        Text(_error!, style: AppTheme.body(color: Colors.red, size: 13)),
      TextField(
        controller: _checkPhone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Mobile number',
          prefixIcon: Icon(Icons.smartphone),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _checkEmail,
        decoration: const InputDecoration(
          labelText: 'Or email',
          prefixIcon: Icon(Icons.mail_outline),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _lookupLoading ? null : _lookup,
        child: _lookupLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Check membership'),
      ),
      if (_lookupResult != null) ...[
        const SizedBox(height: 12),
        FtSectionCard(
          child: Text(
            _lookupResult!['message']?.toString() ?? _lookupResult.toString(),
            style: AppTheme.body(size: 13),
          ),
        ),
      ],
      const SizedBox(height: 22),
      Text('Search families to join',
          style: AppTheme.body(weight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _familyQuery,
              decoration: const InputDecoration(hintText: 'Family name'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppTheme.forest),
            onPressed: _searchFamilies,
            icon: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
      ..._familyResults.map(
        (f) => Card(
          margin: const EdgeInsets.only(top: 8),
          child: ListTile(
            title: Text(f['name']?.toString() ?? 'Family',
                style: AppTheme.body(weight: FontWeight.w700)),
            subtitle: Text(f['hometown']?.toString() ?? ''),
            trailing: TextButton(
              onPressed: () => _joinFamily(f),
              child: Text(
                'Join',
                style: AppTheme.body(
                  weight: FontWeight.w700,
                  color: AppTheme.forest,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: () => context.go('/family/register'),
        child: Text(
          'Create a new family',
          style: AppTheme.body(weight: FontWeight.w700, color: AppTheme.forest),
        ),
      ),
      TextButton(
        onPressed: () => context.go('/family/join'),
        child: Text(
          'Have an invite OTP?',
          style: AppTheme.body(color: AppTheme.muted),
        ),
      ),
    ];
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTheme.body(
              size: 13,
              weight: FontWeight.w700,
              color: selected ? AppTheme.ink : AppTheme.muted,
            ),
          ),
        ),
      ),
    );
  }
}
