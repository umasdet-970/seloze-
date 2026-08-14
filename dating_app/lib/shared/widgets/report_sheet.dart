import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/social_models.dart';

/// Report flow (spec section 11): select reason, add details, submit.
/// Shared between Discover cards and Matches so "Report profile" /
/// "Report message" / "Report photo" all funnel through one UI.
Future<void> showReportSheet(
  BuildContext context, {
  required String targetName,
  required Future<void> Function(ReportReason reason, String details) onSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ReportSheetContent(targetName: targetName, onSubmit: onSubmit),
  );
}

class _ReportSheetContent extends StatefulWidget {
  final String targetName;
  final Future<void> Function(ReportReason reason, String details) onSubmit;

  const _ReportSheetContent({required this.targetName, required this.onSubmit});

  @override
  State<_ReportSheetContent> createState() => _ReportSheetContentState();
}

class _ReportSheetContentState extends State<_ReportSheetContent> {
  ReportReason? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_reason!, _detailsController.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Our team will review it.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report ${widget.targetName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Why are you reporting this profile?', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          ...ReportReason.values.map(
            (r) => RadioListTile<ReportReason>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(r.label),
              value: r,
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Additional details (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: (_reason == null || _submitting) ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}
