import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_auth_repository.dart';
import '../providers/admin_auth_providers.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailController = TextEditingController(text: MockAdminAuthRepository.demoEmail);
  final _passwordController = TextEditingController(text: MockAdminAuthRepository.demoPassword);
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(adminAuthRepositoryProvider).signIn(_emailController.text, _passwordController.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.favorite, color: AppColors.primary, size: 36),
                  const SizedBox(height: 12),
                  const Text('Connect Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  const Text('Internal dashboard — authorized staff only', style: TextStyle(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Demo credentials are pre-filled — real deployment needs role-gated Firebase Auth.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
