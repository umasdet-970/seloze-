# Play Console paste sheet — Seloze-Global Dating App

Go top to bottom. Every value is ready to copy. Details and reasons are in
`play_console_checklist.md`.

## 1. Grow users → Store presence → Main store listing (Create default store listing)

**App name**
```
Seloze-Global Dating App
```

**Short description**
```
Meet people worldwide. Swipe, match and chat in a safe, simple dating app.
```

**Full description**
```
Seloze is a global dating app built around one idea: meeting someone should feel safe, simple, and enjoyable.

Discover people
Swipe through profiles filtered by what you're looking for: age range, distance, and the kind of connection you want. Like, pass, or super-like to stand out. If you allow it, Seloze uses your approximate location to show how far away people are.

Match and start talking
When you both like each other, it's a match. Chat with real-time messaging, photo sharing, and typing indicators.

Built with safety in mind
Block and report tools are on every profile and every chat. Photos and messages are checked automatically for nudity, abuse and spam, and reports are reviewed by our team. Members can request photo verification to earn a trust badge.

Stay in control
Choose who sees your profile, pause your visibility anytime, and manage your notifications. You can delete your account and data at any time from Settings.

Free to use
Seloze is free, with 10 profile discoveries a day. Invite friends to earn more discoveries every day. Premium plans are coming soon.

Seloze is for adults aged 18 and over. Please be respectful and follow our Terms and Conditions.
```

- App icon: `store_listing/graphics/hires_icon_512.png`
- Feature graphic: `store_listing/graphics/feature_graphic_1024x500.png`
- Phone screenshots: retake from the current app (at least 2). Do NOT use `04_paywall.png`.

## 2. Grow users → Store presence → Store settings
- Category: **Dating**
- Contact email: `umamaheswar.sdet@gmail.com`
- Website (optional): `https://connect-dating-app-e2ad4.web.app`

## 3. Policy and programs → App content
| Item | Answer |
|---|---|
| Privacy policy URL | `https://connect-dating-app-e2ad4.web.app/privacy.html` |
| Ads | No |
| Target audience | **18 and over** only, then tick **Restrict minor access** |
| Government apps / Financial features / Health / News | No |
| Data deletion — has in-app deletion | Yes |
| Data deletion — web link | `https://connect-dating-app-e2ad4.web.app/delete-account.html` |

**App access** → "All or some functionality is restricted" → Add instructions:
```
Open the app and tap "Log in". Enter the email and password below. The account already has a complete profile.
Email: <YOUR REVIEWER EMAIL>
Password: <YOUR REVIEWER PASSWORD>
```

**Content rating (IARC)** — answer honestly. Expect these answers:
- Users can interact with each other and share content: **Yes**
- Users can share their location: **Yes**
- Sexual content inside the app itself: **No**
- Violence, drugs, gambling: **No**
- In-app purchases available: **No** (until plans are on sale)

## 4. Data safety
Answer "Yes" to collecting: Name, Email address, Phone number, User IDs, Sexual orientation, Other info (date of birth, gender, bio, profession, education, interests), Approximate location, Photos, Other in-app messages, App interactions, Other user-generated content, Device or other IDs.
- Data encrypted in transit: **Yes**
- Users can request data deletion: **Yes**
- Location and sexual-orientation preferences are **optional**; all others required or app-functional (see checklist for the full table).

## 5. Production → Countries / regions
Start with **India** only.

## 6. Release (Test and release)
1. **Internal testing** → Create release → upload `build/app/outputs/bundle/release/app-release.aab`.
2. Release notes:
```
First release of Seloze.
```
3. **CRITICAL — do this right after the first upload, or Google Sign-In breaks for Play installs.**
   Google re-signs your app with its own key. In Play Console: **Test and release → App integrity → App signing → "App signing key certificate"** → copy the **SHA-1** and **SHA-256**. Then in Firebase console: **Project settings (gear) → General → Your apps → Android app (com.connect.connect_dating_app) → Add fingerprint** → paste each one → Save. (Your own upload-key fingerprint is already registered; this is the second one.)
4. If your account needs it: **Closed testing** → add 12 testers' Gmail addresses → keep them opted in for 14 days → apply for production.
