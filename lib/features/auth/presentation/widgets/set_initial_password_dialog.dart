import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../data/auth_api_service.dart';
import '../providers/auth_providers.dart';

class SetInitialPasswordDialog extends StatefulWidget {
  const SetInitialPasswordDialog({super.key});

  @override
  State<SetInitialPasswordDialog> createState() =>
      _SetInitialPasswordDialogState();
}

class _SetInitialPasswordDialogState extends State<SetInitialPasswordDialog> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    if (_pass.text.length < 8) {
      setState(() {
        _error = 'Password must be at least 8 characters';
        _saving = false;
      });
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() {
        _error = 'Passwords do not match';
        _saving = false;
      });
      return;
    }
    try {
      final api = AuthApiService(context.read<ApiClient>());
      await api.changePassword(newPassword: _pass.text);
      if (!mounted) return;
      context.read<AuthProvider>().clearMustChangePassword();
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Please set a new password before continuing.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
