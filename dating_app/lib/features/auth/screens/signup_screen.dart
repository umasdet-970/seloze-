import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../providers/auth_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _agreedToTerms = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      setState(() => _error = 'You must agree to the Terms & Privacy Policy to continue.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      final analytics = ref.read(analyticsRepositoryProvider);
      analytics.setUserId(user.uid);
      analytics.logEvent('sign_up', params: {'method': 'email'});
      // Router redirect takes it from here (new user -> /age-verify).
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create your account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text("Let's get you set up", style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
                  validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(value: _agreedToTerms, onChanged: (v) => setState(() => _agreedToTerms = v ?? false)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          children: [
                            const Text('I agree to the ', style: TextStyle(fontSize: 13)),
                            GestureDetector(
                              onTap: () => context.push('/legal/terms'),
                              child: const Text('Terms & Conditions',
                                  style: TextStyle(fontSize: 13, color: AppColors.primary, decoration: TextDecoration.underline)),
                            ),
                            const Text(' and ', style: TextStyle(fontSize: 13)),
                            GestureDetector(
                              onTap: () => context.push('/legal/privacy'),
                              child: const Text('Privacy Policy',
                                  style: TextStyle(fontSize: 13, color: AppColors.primary, decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create account'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(onPressed: () => context.pop(), child: const Text('Log in')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
