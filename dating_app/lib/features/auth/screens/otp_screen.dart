import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification_item.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../providers/auth_providers.dart';

/// Phone login (spec section 1). Two internal steps: enter phone number,
/// then enter the OTP sent to it. Mock build accepts code "123456".
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.trim().length < 8) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPhoneOtp(_phoneController.text.trim());
      if (mounted) setState(() => _otpSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).verifyPhoneOtp(
            phoneNumber: _phoneController.text.trim(),
            smsCode: _codeController.text.trim(),
          );
      ref.read(notificationRepositoryProvider).add(
            user.uid,
            NotificationType.securityAlert,
            'New sign-in to your account',
            "If this wasn't you, please secure your account immediately.",
          );
      final analytics = ref.read(analyticsRepositoryProvider);
      analytics.setUserId(user.uid);
      analytics.logEvent('login', params: {'method': 'phone'});
      // Router redirect takes it from here.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _otpSent ? 'Enter the code' : 'Phone login',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'We sent a 6-digit code to ${_phoneController.text.trim()}'
                    : "We'll text you a one-time code",
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              if (!_otpSent)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+91 98765 43210',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: '6-digit code', border: OutlineInputBorder()),
                ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_otpSent ? 'Verify' : 'Send code'),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _otpSent = false),
                  child: const Text('Change phone number'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
