import 'package:flutter/material.dart';

/// Google Play requires an in-app disclosure, and an affirmative action such as
/// ticking a box, BEFORE the app asks for location permission. This is that
/// disclosure. The profile screen starts it unticked and only asks the phone
/// for permission if the person ticks it.
class LocationConsentTile extends StatelessWidget {
  const LocationConsentTile({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: const Text('Use my approximate location', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text(
        'Shows how far away you are from other members. Your location is rounded to about 1 km '
        'before it is saved, and other members only see an approximate distance in km. '
        'Your phone will ask for permission next. You can turn this off at any time.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
