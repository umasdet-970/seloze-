import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../providers/auth_providers.dart';

/// Mandatory age gate (spec section 1) shown once, right after sign-up,
/// before the user can reach Discover. Router redirect enforces this even
/// if the user tries to deep-link elsewhere.
class AgeVerificationScreen extends ConsumerStatefulWidget {
  const AgeVerificationScreen({super.key});

  @override
  ConsumerState<AgeVerificationScreen> createState() => _AgeVerificationScreenState();
}

class _AgeVerificationScreenState extends ConsumerState<AgeVerificationScreen> {
  DateTime? _dateOfBirth;
  bool _loading = false;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    // A new date makes the previous rejection ("must be at least 18")
    // stale — it stayed on screen until Confirm was pressed again.
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _error = null;
      });
    }
  }

  Future<void> _confirm() async {
    if (_dateOfBirth == null) {
      setState(() => _error = 'Select your date of birth');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).setAgeVerified(_dateOfBirth!);
      ref.read(analyticsRepositoryProvider).logEvent('age_verified');
      // Router redirect takes it from here (-> /discover).
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.cake_outlined, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                "What's your date of birth?",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seloze is for adults 18 and over. This stays private and is not shown on your profile.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: _pickDate,
                child: Text(
                  _dateOfBirth == null
                      ? 'Select date of birth'
                      : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _confirm,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
