import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/constants/interests.dart';
import '../../../core/constants/profile_prompts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dating_preferences.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/firebase/firebase_storage_uploader.dart';
import '../../../data/repositories/firebase/location_service.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../discover/providers/discover_providers.dart';
import '../../safety/providers/moderation_providers.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/location_consent_tile.dart';

const _genderOptions = ['Woman', 'Man', 'Non-binary', 'Other'];

/// One in-progress prompt answer in the wizard — a question paired with its
/// own TextEditingController so each entry's field can be edited
/// independently without rebuilding the whole list on every keystroke.
class _PromptDraft {
  String question;
  final TextEditingController controller;
  _PromptDraft(this.question, {String answer = ''}) : controller = TextEditingController(text: answer);
}

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
  final _countryController = TextEditingController();

  String? _gender;
  final Set<String> _interests = {};
  final List<String> _photoUrls = [];
  final List<_PromptDraft> _promptDrafts = [];

  DatingIntention _intention = DatingIntention.notSure;
  RelationshipPreference _relationshipPreference = RelationshipPreference.notSure;
  ShowMePreference _showMe = ShowMePreference.everyone;
  RangeValues _ageRange = const RangeValues(18, 45);
  double _maxDistance = 50;
  bool _visible = true;

  // Location is opt-in (Google Play: an in-app disclosure plus an
  // affirmative tap before the OS permission prompt), so it starts off.
  bool _shareLocation = false;
  bool _hadSavedLocation = false;

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  bool _isEditing = false;
  bool _loadingExisting = true;
  String? _loadError;
  Profile? _existingProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  /// Doubles this wizard as the "Edit profile" screen (spec section 14):
  /// if a profile already exists, prefill every field from it instead of
  /// starting blank. On failure (e.g. a transient network blip), stays on
  /// a retry screen rather than silently proceeding as if there were no
  /// existing profile — that would let _finish() overwrite a real
  /// profile's fields with blanks.
  Future<void> _loadExisting() async {
    setState(() {
      _loadingExisting = true;
      _loadError = null;
    });
    try {
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
        _countryController.text = profile.country;
        _gender = profile.gender.isNotEmpty ? profile.gender : null;
        _interests.addAll(profile.interests);
        _photoUrls.addAll(profile.photoUrls);
        _promptDrafts.addAll(profile.prompts.map((p) => _PromptDraft(p.question, answer: p.answer)));
        _intention = preferences.intention;
        _relationshipPreference = preferences.relationshipPreference;
        _showMe = preferences.showMe;
        _ageRange = RangeValues(preferences.minAge.toDouble(), preferences.maxAge.toDouble());
        _maxDistance = preferences.maxDistanceKm;
        _visible = preferences.profileVisible;
        if (kUseFirebase) {
          _hadSavedLocation = await LocationService().hasSavedLocation(uid);
          _shareLocation = _hadSavedLocation;
        }
      }

      if (mounted) {
        setState(() {
          _existingProfile = profile;
          _isEditing = profile != null;
          _loadingExisting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = "Couldn't load your profile. Check your connection and try again.";
          _loadingExisting = false;
        });
      }
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
    _countryController.dispose();
    for (final draft in _promptDrafts) {
      draft.controller.dispose();
    }
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
      final moderation = ref.read(moderationRepositoryProvider);
      final bioCheck = await moderation.moderateText(_bioController.text);
      if (!bioCheck.allowed) {
        setState(() => _error = bioCheck.reason);
        return;
      }
      // Same gate as the bio — a prompt answer is just as visible to other
      // members and just as able to carry abuse/spam if it went unchecked.
      for (final draft in _promptDrafts) {
        final answer = draft.controller.text.trim();
        if (answer.isEmpty) continue;
        final promptCheck = await moderation.moderateText(answer);
        if (!promptCheck.allowed) {
          setState(() => _error = promptCheck.reason);
          return;
        }
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
        country: _countryController.text.trim(),
        prompts: [
          for (final draft in _promptDrafts)
            if (draft.controller.text.trim().isNotEmpty)
              ProfilePrompt(question: draft.question, answer: draft.controller.text.trim()),
        ],
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
      // Discover's default filters come from these preferences.
      ref.invalidate(datingPreferencesProvider);
      ref
          .read(analyticsRepositoryProvider)
          .logEvent(_isEditing ? 'profile_edited' : 'profile_completed');

      // Real geo-distance in Discover (spec section 4/15) — best-effort,
      // deliberately not awaited: a slow GPS fix must never delay
      // finishing onboarding, and LocationService already never throws
      // (permission denied / location off / any failure just means no
      // location gets saved, not an error surfaced here).
      if (kUseFirebase) {
        final location = LocationService();
        if (_shareLocation) {
          unawaited(location.captureAndSaveLocation(uid));
        } else if (_hadSavedLocation) {
          // They switched it off — stop keeping the location we had.
          unawaited(location.clearSavedLocation(uid));
        }
      }
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

  /// Runs a freshly picked/uploaded photo through moderation and either
  /// appends it (a new photo) or overwrites [replaceIndex] (replacing an
  /// existing one) — the one commit path both "add" and "replace" share,
  /// so neither can bypass the moderation gate the other goes through.
  Future<void> _commitPhoto(String pathOrUrl, {int? replaceIndex}) async {
    final moderation = await ref.read(moderationRepositoryProvider).moderatePhoto(pathOrUrl);
    if (!moderation.allowed) {
      if (mounted) setState(() => _error = moderation.reason);
      return;
    }
    if (!mounted) return;
    setState(() {
      if (replaceIndex != null) {
        _photoUrls[replaceIndex] = pathOrUrl;
      } else if (!_photoUrls.contains(pathOrUrl)) {
        _photoUrls.add(pathOrUrl);
      }
      _error = null;
    });
  }

  /// Opens the real device camera/gallery (never a URL field, never a
  /// sample photo) and commits whatever comes back. [replaceIndex] set
  /// means "replace this existing photo" instead of adding a new one —
  /// same picker, same upload/commit path either way.
  Future<void> _pickPhoto(ImageSource source, {int? replaceIndex}) async {
    final ImagePicker picker;
    try {
      picker = ImagePicker();
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't open the photo picker. Please try again.");
      return;
    }

    XFile? picked;
    try {
      picked = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    } on PlatformException catch (e) {
      // camera_access_denied / photo_access_denied (permission refused),
      // or any other platform-side failure — surfaced, not silently
      // swallowed, since the user explicitly asked for a photo and
      // nothing happened. A plain cancel (picked == null below) is NOT
      // an error and must stay silent.
      if (mounted) {
        setState(() {
          _error = e.code.contains('denied')
              ? 'Camera/photo permission was denied. Enable it in your phone\'s Settings to add photos.'
              : "Couldn't access the camera or gallery. Please try again.";
        });
      }
      return;
    }
    if (picked == null) return; // user cancelled — not an error, nothing to show

    setState(() => _uploadingPhoto = true);
    try {
      if (kUseFirebase) {
        final uid = ref.read(currentUserIdProvider);
        final url = await FirebaseStorageUploader().uploadProfilePhoto(uid, File(picked.path));
        await _commitPhoto(url, replaceIndex: replaceIndex);
      } else {
        // No Firebase project connected in this build (kUseFirebase is
        // off) — the photo is still 100% real (picked from the device's
        // own camera/gallery, never a sample), just kept as a local file
        // path instead of an uploaded HTTPS URL. Once kUseFirebase is
        // flipped on for a real launch, every photo goes through the
        // Storage upload branch above instead.
        await _commitPhoto(picked.path, replaceIndex: replaceIndex);
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't upload that photo. Please try again.");
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _showPhotoSourceSheet({int? replaceIndex}) async {
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
    if (source != null) await _pickPhoto(source, replaceIndex: replaceIndex);
  }

  void _removePhoto(int index) {
    setState(() {
      _photoUrls.removeAt(index);
      _error = null;
    });
  }

  /// `Profile.photoUrls` holds plain HTTPS URLs once uploaded to Firebase
  /// Storage, but a local file path (kUseFirebase off — see _pickPhoto)
  /// needs `Image.file`, not `Image.network`, to actually render.
  Widget _photoThumbnail(String pathOrUrl) {
    final isRemoteUrl = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
    if (isRemoteUrl) {
      return Image.network(pathOrUrl, width: 100, height: 100, fit: BoxFit.cover);
    }
    return Image.file(File(pathOrUrl), width: 100, height: 100, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _loadExisting, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
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
          const SizedBox(height: 4),
          const _RequiredHint(),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(label: _requiredLabel('Name'), border: const OutlineInputBorder()),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          const Text.rich(
            TextSpan(
              text: 'Gender',
              style: TextStyle(fontWeight: FontWeight.w600),
              children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _genderOptions.map((g) {
              return ChoiceChip(
                label: Text(g),
                selected: _gender == g,
                onSelected: (_) => setState(() {
                  _gender = g;
                  _error = null;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: InputDecoration(label: _requiredLabel('Bio'), border: const OutlineInputBorder()),
            onChanged: (_) => setState(() => _error = null),
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
          _buildPromptsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Optional Hinge-style prompts (spec: up to kMaxProfilePrompts, each a
  /// picked question + free-text answer) — see _PromptDraft and
  /// core/constants/profile_prompts.dart. Never required to advance, unlike
  /// name/gender/bio above.
  Widget _buildPromptsSection() {
    final usedQuestions = _promptDrafts.map((d) => d.question).toSet();
    final availableQuestions = kProfilePromptQuestions.where((q) => !usedQuestions.contains(q)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Prompts (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Answer up to $kMaxProfilePrompts to help you stand out and give matches something to reply to.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _promptDrafts.length; i++) _buildPromptCard(i, availableQuestions),
        if (_promptDrafts.length < kMaxProfilePrompts && availableQuestions.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => setState(() => _promptDrafts.add(_PromptDraft(availableQuestions.first))),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add a prompt'),
          ),
      ],
    );
  }

  Widget _buildPromptCard(int index, List<String> availableQuestions) {
    final draft = _promptDrafts[index];
    // The dropdown must always include the currently-selected question even
    // if it's not in `availableQuestions` (every OTHER draft's pick is
    // excluded from that list so the same question can't be picked twice).
    final options = {draft.question, ...availableQuestions}.toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.question,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Prompt', isDense: true),
                    items: [
                      for (final q in options) DropdownMenuItem(value: q, child: Text(q, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => draft.question = v ?? draft.question),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove prompt',
                  onPressed: () => setState(() {
                    draft.controller.dispose();
                    _promptDrafts.removeAt(index);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: draft.controller,
              maxLines: 2,
              maxLength: 150,
              decoration: const InputDecoration(hintText: 'Your answer', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            const TextSpan(
              text: 'Add photos',
              children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
            ),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add at least 1 photo from your camera or gallery. Tap a photo to replace it, or the × to remove it.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < _photoUrls.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: _uploadingPhoto ? null : () => _showPhotoSourceSheet(replaceIndex: i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _photoThumbnail(_photoUrls[i]),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: _uploadingPhoto ? null : () => _removePhoto(i),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black87,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              // The "purple +" add-photo tile — always opens the real
              // device camera/gallery picker, never a URL field or a
              // sample image.
              GestureDetector(
                onTap: _uploadingPhoto ? null : () => _showPhotoSourceSheet(),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                    color: AppColors.primary.withValues(alpha: 0.06),
                  ),
                  child: Center(
                    child: _uploadingPhoto
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.add, color: AppColors.primary, size: 32),
                  ),
                ),
              ),
            ],
          ),
          if (_uploadingPhoto)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Uploading and checking your photo — this can take a few seconds…',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Kept as free text (not a picker) to support ~180 countries
                // without bundling a country-list dependency; admin
                // country-wise stats group on this value verbatim, so
                // consistent spelling matters more at scale than it does here.
                child: TextField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LocationConsentTile(
            value: _shareLocation,
            onChanged: (v) => setState(() => _shareLocation = v),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 4),
          const Text(
            'Only used to filter who you see. It is private and never shown on your profile.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
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

/// Field label with a red asterisk — marks the fields the wizard actually
/// refuses to continue without (see `_canAdvance`): name, gender, bio and
/// at least one photo. Everything else is optional.
Widget _requiredLabel(String text) {
  return Text.rich(
    TextSpan(
      text: text,
      children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
    ),
  );
}

/// Legend for the asterisk, shown once above the first required field.
class _RequiredHint extends StatelessWidget {
  const _RequiredHint();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '*', style: TextStyle(color: Colors.red)),
          TextSpan(text: ' Required'),
        ],
      ),
      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
    );
  }
}
