import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Renders a Privacy Policy / Terms / Community Guidelines document. Content
/// uses '## ' as a section-heading marker and '- ' for bullet points;
/// everything else is body text. A heading may sit on the line directly above
/// its body text (no blank line between them), so the document is read line by
/// line rather than split on blank lines.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ..._buildWidgets(content),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static List<Widget> _buildWidgets(String content) {
    final widgets = <Widget>[];
    final paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            paragraph.join('\n'),
            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textDark),
          ),
        ),
      );
      paragraph.clear();
    }

    for (final raw in content.trim().split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('## ')) {
        flush();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(line.substring(3), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        );
      } else if (line.isEmpty) {
        flush();
      } else {
        paragraph.add(line.startsWith('- ') ? '•  ${line.substring(2)}' : line);
      }
    }
    flush();
    return widgets;
  }
}
