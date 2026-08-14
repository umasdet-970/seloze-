import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/interests.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/discover_filters.dart';
import '../../../data/models/subscription_models.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../providers/discover_providers.dart';

/// Search & Filters (spec section 15). Basic filters are free; the rest
/// are gated behind Premium, matching the "Premium filters" benefit.
Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => const _FilterSheetContent(),
  );
}

class _FilterSheetContent extends ConsumerStatefulWidget {
  const _FilterSheetContent();

  @override
  ConsumerState<_FilterSheetContent> createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends ConsumerState<_FilterSheetContent> {
  late DiscoverFilters _draft;
  late final TextEditingController _searchController;
  late final TextEditingController _professionController;
  late final TextEditingController _educationController;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(discoverFiltersProvider);
    _searchController = TextEditingController(text: _draft.searchQuery);
    _professionController = TextEditingController(text: _draft.profession);
    _educationController = TextEditingController(text: _draft.education);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _professionController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(discoverFiltersProvider.notifier).state = _draft.copyWith(
      searchQuery: _searchController.text.trim(),
      profession: _professionController.text.trim(),
      education: _educationController.text.trim(),
    );
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _draft = const DiscoverFilters();
      _searchController.clear();
      _professionController.clear();
      _educationController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(subscriptionTierProvider) == SubscriptionTier.premium;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Search & Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(onPressed: _reset, child: const Text('Reset')),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by name, profession, education',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Age range: ${_draft.minAge} - ${_draft.maxAge}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      RangeSlider(
                        values: RangeValues(_draft.minAge.toDouble(), _draft.maxAge.toDouble()),
                        min: 18,
                        max: 80,
                        divisions: 62,
                        labels: RangeLabels('${_draft.minAge}', '${_draft.maxAge}'),
                        onChanged: (v) => setState(() => _draft = _draft.copyWith(minAge: v.start.round(), maxAge: v.end.round())),
                      ),
                      const SizedBox(height: 8),
                      Text('Maximum distance: ${_draft.maxDistanceKm.round()} km', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Slider(
                        value: _draft.maxDistanceKm,
                        min: 1,
                        max: 200,
                        divisions: 199,
                        label: '${_draft.maxDistanceKm.round()} km',
                        onChanged: (v) => setState(() => _draft = _draft.copyWith(maxDistanceKm: v)),
                      ),
                      const SizedBox(height: 12),
                      const Text('Show me', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: GenderFilter.values.map((g) {
                          return ChoiceChip(
                            label: Text(g.label),
                            selected: _draft.gender == g,
                            onSelected: (_) => setState(() => _draft = _draft.copyWith(gender: g)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text('Premium filters', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                            child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isPremium)
                        _PremiumFiltersLock(onUpgrade: () {
                          Navigator.pop(context);
                          context.push('/paywall');
                        })
                      else
                        _PremiumFiltersFields(
                          draft: _draft,
                          professionController: _professionController,
                          educationController: _educationController,
                          onChanged: (d) => setState(() => _draft = d),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _apply, child: const Text('Apply filters')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumFiltersLock extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _PremiumFiltersLock({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.primary),
          const SizedBox(height: 8),
          const Text(
            'Verified-only, online-only, profession, education, and interest filters are Premium.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onUpgrade, child: const Text('Upgrade to Premium')),
        ],
      ),
    );
  }
}

class _PremiumFiltersFields extends StatelessWidget {
  final DiscoverFilters draft;
  final TextEditingController professionController;
  final TextEditingController educationController;
  final ValueChanged<DiscoverFilters> onChanged;

  const _PremiumFiltersFields({
    required this.draft,
    required this.professionController,
    required this.educationController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Verified profiles only'),
          value: draft.verifiedOnly,
          onChanged: (v) => onChanged(draft.copyWith(verifiedOnly: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Online now'),
          value: draft.onlineOnly,
          onChanged: (v) => onChanged(draft.copyWith(onlineOnly: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: professionController,
          decoration: const InputDecoration(labelText: 'Profession', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: educationController,
          decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        const Text('Interests', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kInterestOptions.map((interest) {
            final selected = draft.interests.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: selected,
              onSelected: (v) {
                final updated = Set<String>.from(draft.interests);
                if (v) {
                  updated.add(interest);
                } else {
                  updated.remove(interest);
                }
                onChanged(draft.copyWith(interests: updated));
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
