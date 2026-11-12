import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/family_api_service.dart';

class FamilyVerifyOtpScreen extends StatefulWidget {
  const FamilyVerifyOtpScreen({super.key, this.extras = const {}});

  final Map<String, dynamic> extras;

  @override
  State<FamilyVerifyOtpScreen> createState() => _FamilyVerifyOtpScreenState();
}

class _FamilyVerifyOtpScreenState extends State<FamilyVerifyOtpScreen> {
  final _otp = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _otp.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = {
        ...widget.extras,
        'otp': _otp.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
      };
      final res =
          await context.read<FamilyApiService>().verifyFamilyOtp(payload);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final token = data['token']?.toString();
      final userMap = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : null;
      if (token != null && token.isNotEmpty) {
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

  Future<void> _resend() async {
    try {
      await context.read<FamilyApiService>().resendFamilyOtp(widget.extras);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.extras['email'] ?? widget.extras['phone'] ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Enter the OTP sent to $contact'),
          const SizedBox(height: 12),
          TextField(
            controller: _otp,
            decoration: const InputDecoration(labelText: 'OTP'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Set password (optional)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _verify,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify & continue'),
          ),
          TextButton(onPressed: _resend, child: const Text('Resend OTP')),
        ],
      ),
    );
  }
}
