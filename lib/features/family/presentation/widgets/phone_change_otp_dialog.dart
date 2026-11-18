import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';
import '../../../../core/network/api_exception.dart';

/// OTP dialog for verifying a new mobile before it becomes the login number.
Future<bool> showPhoneChangeOtpDialog({
  required BuildContext context,
  required String phone,
  String title = 'Verify new mobile',
  String? description,
  required Future<void> Function(String phone) onRequestOtp,
  required Future<void> Function(String phone, String otp) onVerifyOtp,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PhoneChangeOtpDialog(
      phone: phone,
      title: title,
      description: description,
      onRequestOtp: onRequestOtp,
      onVerifyOtp: onVerifyOtp,
    ),
  );
  return result == true;
}

class _PhoneChangeOtpDialog extends StatefulWidget {
  const _PhoneChangeOtpDialog({
    required this.phone,
    required this.title,
    required this.onRequestOtp,
    required this.onVerifyOtp,
    this.description,
  });

  final String phone;
  final String title;
  final String? description;
  final Future<void> Function(String phone) onRequestOtp;
  final Future<void> Function(String phone, String otp) onVerifyOtp;

  @override
  State<_PhoneChangeOtpDialog> createState() => _PhoneChangeOtpDialogState();
}

class _PhoneChangeOtpDialogState extends State<_PhoneChangeOtpDialog> {
  final _otp = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _sent = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendInitial());
  }

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  String _msg(Object e) {
    if (e is ApiException) return e.message;
    return e.toString();
  }

  Future<void> _sendInitial() async {
    if (_sending || _sent) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onRequestOtp(widget.phone);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _info = 'OTP sent to +91 ${widget.phone}';
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context, false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(e))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onRequestOtp(widget.phone);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _info = 'OTP resent to +91 ${widget.phone}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _otp.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.onVerifyOtp(widget.phone, code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desc = widget.description ??
        'OTP will be sent to +91 ${widget.phone}. Verify to make this your login mobile.';

    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(widget.title, style: AppTheme.display(size: 18)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              desc,
              style: AppTheme.body(size: 13, color: AppTheme.muted),
            ),
            const SizedBox(height: 14),
            if (_sending && !_sent)
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sending OTP…',
                    style: AppTheme.body(size: 13, color: AppTheme.muted),
                  ),
                ],
              )
            else ...[
              TextField(
                controller: _otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTheme.body(
                  size: 20,
                  weight: FontWeight.w700,
                ).copyWith(letterSpacing: 8),
                decoration: const InputDecoration(
                  labelText: '6-digit OTP',
                  counterText: '',
                  hintText: '••••••',
                ),
                onSubmitted: (_) => _verify(),
              ),
              TextButton(
                onPressed: _sending ? null : _resend,
                child: Text(
                  _sending ? 'Sending…' : 'Resend OTP',
                  style: AppTheme.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppTheme.forest,
                  ),
                ),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 4),
              Text(
                _info!,
                style: AppTheme.body(size: 12, color: AppTheme.emerald600),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: AppTheme.body(size: 12, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.forest),
          onPressed: _verifying ||
                  _otp.text.replaceAll(RegExp(r'\D'), '').length != 6
              ? null
              : _verify,
          child: _verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Verify & update'),
        ),
      ],
    );
  }
}
