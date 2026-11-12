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
  String? _invitationId;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
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
        _info = data['message']?.toString() ?? 'Invitation found. Enter OTP.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_invitationId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<FamilyApiService>().verifyInviteOtp(
        _invitationId!,
        {'otp': _otp.text.trim(), 'email': _email.text.trim().toLowerCase()},
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
      context.go('/dashboard');
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
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Invite email'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _lookup,
            child: const Text('Lookup invitation'),
          ),
          if (_info != null) ...[
            const SizedBox(height: 12),
            Text(_info!),
          ],
          if (_invitationId != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otp,
              decoration: const InputDecoration(labelText: 'OTP'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: const Text('Verify & join'),
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
