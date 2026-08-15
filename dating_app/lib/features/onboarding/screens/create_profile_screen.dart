import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/constants/interests.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dating_preferences.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/firebase/firebase_storage_uploader.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../../safety/providers/moderation_providers.dart';
import '../providers/onboarding_providers.dart';

const _genderOptions = ['Woman', 'Man', 'Non-binary', 'Other'];

const _samplePhotoUrls = [
  'https://images.unsplash.com/photo-1552374196-c4e7ffc6e126?w=800',
  'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=800',
  'https://images.unsplash.com/photo-1607746882042-944635dfe10e?w=800',
];

/// Core user flow steps 3-5 (spec section 23): create profile, upload
/// photos, set location & preferences — one gate before Discover unlocks.
class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const _totalSteps = 3;

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _professionController = TextEditingController();
  final _educationController = TextEditingController();
  final _cityController = TextEditingController();
  final _photoUrlController = TextEditingController();

  String? _gender;
  final Set<String> _interests = {};
  final List<String> _photoUrls = [];

  DatingIntention _intention = DatingIntention.notSure;
  RelationshipPreference _relationshipPreference = RelationshipPreference.notSure;
  ShowMePreference _showMe = ShowMePreference.everyone;
  RangeValues _ageRange = const RangeValues(18, 45);
  double _maxDistance = 50;
  bool _visible = true;

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  bool _isEditing = false;
  bool _loadingExisting = true;
  Profile? _existingProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  /// Doubles this wizard as the "Edit profile" screen (spec section 14):
  /// if a profile already exists, prefill every field from it instead of
  /// starting blank.
  Future<void> _loadExisting() async {
    final uid = ref.read(currentUserIdProvider);
    final repo = ref.read(userProfileRepositoryProvider);
    final profile = await repo.fetchMyProfile(uid);
    final preferences = await repo.fetchPreferences(uid);

    if (profile != null) {
      _nameController.text = profile.name;
      _bioController.text = profile.bio;
      _professionController.text = profile.profession;
      _educationController.text = profile.education;
      _cityController.text = profile.city;
      _gender = profile.gender.isNotEmpty ? profile.gender : null;
      _interests.addAll(profile.interests);
      _photoUrls.addAll(profile.photoUrls);
      _intention = preferences.intention;
      _relationshipPreference = preferences.relationshipPreference;
      _showMe = preferences.showMe;
      _ageRange = RangeValues(preferences.minAge.toDouble(), preferences.maxAge.toDouble());
      _maxDistance = preferences.maxDistanceKm;
      _visible = preferences.profileVisible;
    }

    if (mounted) {
      setState(() {
        _existingProfile = profile;
        _isEditing = profile != null;
        _loadingExisting = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _professionController.dispose();
    _educationController.dispose();
    _cityController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    if (_step == 0) {
      return _nameController.text.trim().isNotEmpty && _gender != null && _bioController.text.trim().isNotEmpty;
    }
    if (_step == 1) {
      return _photoUrls.isNotEmpty;
    }
    return true;
  }

  Future<void> _next() async {
    if (!_canAdvance) {
      setState(() => _error = _step == 0 ? 'Add your name, gender and a short bio' : 'Add at least one photo');
      return;
    }

    if (_step == 0) {
      final moderation = await ref.read(moderationRepositoryProvider).moderateText(_bioController.text);
      if (!moderation.allowed) {
        setState(() => _error = moderation.reason);
        return;
      }
    }

    setState(() => _error = null);
    if (_step == _totalSteps - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _pageController.animateToPage(_step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _error = null;
    });
    _pageController.animateToPage(_step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  int _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      final dob = ref.read(authStateChangesProvider).valueOrNull?.dateOfBirth;
      final age = dob != null ? _ageFromDob(dob) : 18;

      // Preserve isVerified/isOnline/distanceKm/company when editing an
      // existing profile — only the fields this wizard collects change.
      final base = _existingProfile ??
          Profile(
            id: uid,
            name: '',
            age: age,
            profession: '',
            company: '',
            education: '',
            bio: '',
            photoUrls: const [],
            interests: const [],
            distanceKm: 0,
            isOnline: true,
          );
      final profile = base.copyWith(
        name: _nameController.text.trim(),
        age: age,
        gender: _gender!,
        profession: _professionController.text.trim(),
        education: _educationController.text.trim(),
        bio: _bioController.text.trim(),
        photoUrls: _photoUrls,
        interests: _interests.toList(),
        city: _cityController.text.trim(),
      );
      final preferences = DatingPreferences(
        intention: _intention,
        relationshipPreference: _relationshipPreference,
        showMe: _showMe,
        minAge: _ageRange.start.round(),
        maxAge: _ageRange.end.round(),
        maxDistanceKm: _maxDistance,
        profileVisible: _visible,
      );

      final repo = ref.read(userProfileRepositoryProvider);
      await repo.saveProfile(uid, profile);
      await repo.savePreferences(uid, preferences);
      ref
          .read(analyticsRepositoryProvider)
          .logEvent(_isEditing ? 'profile_edited' : 'profile_completed');
      // Onboarding: router redirect takes it from here (-> /discover).
      // Editing: profile was already complete, so redirect won't fire —
      // just return to wherever Edit Profile was opened from.
      if (_isEditing && mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPhotoUrl(String url) async {
    if (url.trim().isEmpty || _photoUrls.contains(url.trim())) return;
    final moderation = await ref.read(moderationRepositoryProvider).moderatePhoto(url.trim());
    if (!moderation.allowed) {
      setState(() => _error = moderation.reason);
      return;
    }
    setState(() {
      _photoUrls.add(url.trim());
      _photoUrlController.clear();
      _error = null;
    });
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      final url = await FirebaseStorageUploader().uploadProfilePhoto(uid, File(picked.path));
      await _addPhotoUrl(url);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't upload that photo. Please try again.");
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickAndUploadPhoto(source);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: _isEditing ? AppBar(title: const Text('Edit profile')) : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step ${_step + 1} of $_totalSteps', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: (_step + 1) / _totalSteps, minHeight: 6),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAboutYouStep(),
                  _buildPhotosStep(),
                  _buildPreferencesStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(onPressed: _saving ? null : _back, child: const Text('Back')),
                        ),
                      if (_step > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _saving ? null : _next,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_step == _totalSteps - 1 ? 'Finish' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutYouStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About you', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _genderOptions.map((g) {
              return ChoiceChip(
                label: Text(g),
                selected: _gender == g,
                onSelected: (_) => setState(() => _gender = g),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _professionController,
            decoration: const InputDecoration(labelText: 'Profession', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _educationController,
            decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          const Text('Interests', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kInterestOptions.map((interest) {
              final selected = _interests.contains(interest);
              return FilterChip(
                label: Text(interest),
                selected: selected,
                onSelected: (v) => setState(() => v ? _interests.add(interest) : _interests.remove(interest)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPhotosStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add photos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            kUseFirebase
                ? 'Add at least 1 photo from your camera or gallery.'
                : 'Add at least 1 photo. (Mock build: paste an image URL — flip kUseFirebase once '
                    'Firebase Storage is configured to upload real photos here instead.)',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (kUseFirebase)
            OutlinedButton.icon(
              onPressed: _uploadingPhoto ? null : _showPhotoSourceSheet,
              icon: _uploadingPhoto
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_uploadingPhoto ? 'Uploading...' : 'Add a photo'),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _photoUrlController,
                    decoration: const InputDecoration(labelText: 'Image URL', border: OutlineInputBorder()),
                    onSubmitted: _addPhotoUrl,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _addPhotoUrl(_photoUrlController.text),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _samplePhotoUrls.map((url) {
                return ActionChip(
                  avatar: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('Use sample photo'),
                  onPressed: () => _addPhotoUrl(url),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          if (_photoUrls.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _photoUrls.map((url) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: () => setState(() => _photoUrls.remove(url)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black87,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location & preferences',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'City, Country',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Dating intention', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: DatingIntention.values.map((v) {
              return ChoiceChip(
                label: Text(v.label),
                selected: _intention == v,
                onSelected: (_) => setState(() => _intention = v),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Relationship preference', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: RelationshipPreference.values.map((v) {
              return ChoiceChip(
                label: Text(v.label),
                selected: _relationshipPreference == v,
                onSelected: (_) => setState(() => _relationshipPreference = v),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Show me', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ShowMePreference.values.map((v) {
              return ChoiceChip(
                label: Text(v.label),
                selected: _showMe == v,
                onSelected: (_) => setState(() => _showMe = v),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('Age range: ${_ageRange.start.round()} - ${_ageRange.end.round()}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 80,
            divisions: 62,
            labels: RangeLabels('${_ageRange.start.round()}', '${_ageRange.end.round()}'),
            onChanged: (v) => setState(() => _ageRange = v),
          ),
          const SizedBox(height: 12),
          Text('Maximum distance: ${_maxDistance.round()} km', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _maxDistance,
            min: 1,
            max: 200,
            divisions: 199,
            label: '${_maxDistance.round()} km',
            onChanged: (v) => setState(() => _maxDistance = v),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show my profile in Discover'),
            subtitle: const Text('Turn off to pause visibility without deleting your profile'),
            value: _visible,
            onChanged: (v) => setState(() => _visible = v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
