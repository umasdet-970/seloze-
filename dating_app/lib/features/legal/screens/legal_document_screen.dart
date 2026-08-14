import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Renders a Privacy Policy / Terms document (spec section 26). Content
/// uses '## ' as a section-heading marker; everything else is body text.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final blocks = content.trim().split('\n\n');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final block in blocks) _buildBlock(block.trim()),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'This is a draft prepared for the app scaffold — have it reviewed by a '
                'qualified lawyer for your launch jurisdictions before publishing.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(String block) {
    if (block.isEmpty) return const SizedBox.shrink();
    if (block.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(block.substring(3), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(block, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textDark)),
    );
  }
}
