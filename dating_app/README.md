# Connect — Dating App (MVP scaffold)

Phase 1 of the build: Flutter + Riverpod + GoRouter, running on **mock data**
(no Firebase yet) so you can `flutter run` immediately and see the Discover
screen working end-to-end (swipe, like/pass, match dialog).

## Run it

```bash
flutter pub get
flutter run
```

Requires Flutter 3.19+ (Dart 3.3+). If `flutter_card_swiper` or
`google_fonts` fail to resolve, run `flutter pub upgrade`.

## What's wired up

- `lib/main.dart` — app entry, ProviderScope, theme
- `lib/core/router/app_router.dart` — GoRouter with bottom-nav shell
- `lib/core/theme/app_theme.dart` — colors matching your mockup (purple
  accent, pink like button, purple super-like)
- `lib/features/discover/` — full Discover screen: swipe cards, tab chips,
  like/pass/super-like buttons, match dialog
- `lib/data/repositories/profile_repository.dart` — **this is the seam**.
  `MockProfileRepository` returns hardcoded profiles. When you're ready for
  Firebase, write `FirestoreProfileRepository implements ProfileRepository`
  and swap one line in `discover_providers.dart`. No widget code changes.
- `lib/features/{likes,matches,chat,profile}/` — placeholder screens, wired
  into navigation, ready for you to fill in next

## Next steps (in order)

1. **Run this and confirm it matches your mockup** — tell me what's off
2. **Firebase setup**: `firebase_core`, `firebase_auth`, `cloud_firestore` —
   I'll write `FirestoreProfileRepository` + security rules
3. **Auth screens**: email/phone OTP/social login (spec section 1)
4. **Profile creation flow**: multi-step form + photo upload (spec section 2)
5. **Matches + Chat**: real-time Firestore listeners
6. **RevenueCat**: Premium/Ad-Free subscription gating (spec section 8-9)
7. **Admin dashboard**: separate Flutter Web or React app

## Notes on the architecture

- **Repository pattern everywhere.** No widget calls Firestore/HTTP
  directly — they go through a repository interface. This is what makes
  "swap mock data for real backend" a one-line change instead of a rewrite.
- **Riverpod AsyncNotifier** for the feed state — handles loading/error/data
  states without manual boilerplate.
- Photos currently load from Unsplash URLs (placeholder). Swap for
  Firebase Storage URLs once uploads are wired in.
