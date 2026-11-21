import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/family_api_service.dart';

class FamilyJoinScreen extends StatefulWidget {
  const FamilyJoinScreen({super.key});

  @override
  State<FamilyJoinScreen> createState() => _FamilyJoinScreenState();
}

class _FamilyJoinScreenState extends State<FamilyJoinScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  String? _invitationId;
  String? _familyName;
  String? _relationship;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await context
          .read<FamilyApiService>()
          .lookupInvitation(_email.text.trim().toLowerCase());
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      setState(() {
        _invitationId =
            (data['invitationId'] ?? data['id'] ?? data['invitation']?['id'])
                ?.toString();
        _familyName = data['familyName']?.toString();
        _relationship = data['relationship']?.toString();
        _info = data['message']?.toString() ??
            'Invitation found. Enter OTP and create a password.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_invitationId == null) return;
    final otp = _otp.text.trim();
    final password = _password.text;
    if (otp.length < 4) {
      setState(() => _error = 'Enter the 6-digit OTP.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<FamilyApiService>().verifyInviteOtp(
        _invitationId!,
        {
          'otp': otp,
          'email': _email.text.trim().toLowerCase(),
          'password': password,
        },
      );
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final token = data['token']?.toString();
      final userMap = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : null;
      if (token != null) {
        await context.read<AuthProvider>().adoptSession(
              token: token,
              sessionUser:
                  userMap == null ? null : AuthUser.fromJson(userMap),
            );
      }
      if (!mounted) return;
      context.go('/family/media');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join with invite'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Enter the email that received the OTP, then the code and a new password.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Invite email'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _lookup,
            child: Text(_loading && _invitationId == null
                ? 'Looking up...'
                : 'Lookup invitation'),
          ),
          if (_info != null) ...[
            const SizedBox(height: 12),
            Text(_info!),
          ],
          if (_invitationId != null) ...[
            if (_familyName != null || _relationship != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  [
                    if (_familyName != null) 'Invited to $_familyName',
                    if (_relationship != null) 'as $_relationship',
                  ].join(' '),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Create password (min 8)',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: Text(_loading ? 'Joining...' : 'Verify OTP & Join'),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _invitationId = null;
                        _otp.clear();
                        _password.clear();
                        _info = null;
                        _error = null;
                      }),
              child: const Text('Use a different email'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
