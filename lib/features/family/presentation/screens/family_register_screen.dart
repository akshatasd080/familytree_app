import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/phone_utils.dart';
import '../../data/family_api_service.dart';

class FamilyRegisterScreen extends StatefulWidget {
  const FamilyRegisterScreen({super.key});

  @override
  State<FamilyRegisterScreen> createState() => _FamilyRegisterScreenState();
}

class _FamilyRegisterScreenState extends State<FamilyRegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _familyName = TextEditingController();
  String _contactMethod = 'email';
  String? _gender;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _familyName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    if (_gender == null) {
      setState(() {
        _error = 'Choose Male, Female, or Other';
        _loading = false;
      });
      return;
    }
    if (_contactMethod == 'phone' && !isValidIndianMobile(_phone.text)) {
      setState(() {
        _error = 'Enter a valid 10-digit mobile number';
        _loading = false;
      });
      return;
    }
    if (_contactMethod == 'email' && _email.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter your email';
        _loading = false;
      });
      return;
    }
    try {
      final payload = {
        'name': _name.text.trim(),
        'familyName': _familyName.text.trim(),
        'gender': _gender,
        'contactMethod': _contactMethod,
        if (_contactMethod == 'phone')
          'phone': _phone.text.replaceAll(RegExp(r'\D'), '')
        else
          'email': _email.text.trim().toLowerCase(),
      };
      final res =
          await context.read<FamilyApiService>().registerFamily(payload);
      final message = res.data is Map
          ? (res.data['message']?.toString() ?? 'OTP sent')
          : 'OTP sent';
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      context.go('/family/verify-otp', extra: {
        ...payload,
        'registrationId': res.data is Map ? res.data['registrationId'] : null,
      });
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
        title: const Text('Create family'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _familyName,
            decoration: const InputDecoration(labelText: 'Family name'),
          ),
          const SizedBox(height: 12),
          const Text('Gender'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Male', 'Female', 'Other'].map((g) {
              return ChoiceChip(
                label: Text(g),
                selected: _gender == g,
                onSelected: (_) => setState(() => _gender = g),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'email', label: Text('Email'), icon: Icon(Icons.mail)),
              ButtonSegment(value: 'phone', label: Text('Phone'), icon: Icon(Icons.phone)),
            ],
            selected: {_contactMethod},
            onSelectionChanged: (s) =>
                setState(() => _contactMethod = s.first),
          ),
          const SizedBox(height: 12),
          if (_contactMethod == 'email')
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            )
          else
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Mobile'),
              keyboardType: TextInputType.phone,
              onChanged: (v) {
                final digits = v.replaceAll(RegExp(r'\D'), '').substring(
                      0,
                      v.replaceAll(RegExp(r'\D'), '').length.clamp(0, 10),
                    );
                if (digits != v) {
                  _phone.value = TextEditingValue(
                    text: digits,
                    selection: TextSelection.collapsed(offset: digits.length),
                  );
                }
              },
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send OTP'),
          ),
        ],
      ),
    );
  }
}
