# Google Play Console checklist — Seloze-Global Dating App

Built from Google's own policy pages (read September 2026). Play policies
change, so re-check each item against the live Play Console help before you
submit. This is a working checklist, not legal advice — have a lawyer review
the Terms / Privacy Policy / Community Guidelines before you launch in each
country.

Sources:
- User Generated Content: https://support.google.com/googleplay/android-developer/answer/9876937
- Moderation requirements for UGC apps: https://support.google.com/googleplay/android-developer/answer/12923286
- Age-Restricted Content and Functionality (dating): https://support.google.com/googleplay/android-developer/answer/16302250
- Target audience / Restrict Minor Access: https://support.google.com/googleplay/android-developer/answer/9867159
- Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- User Data policy: https://support.google.com/googleplay/android-developer/answer/10144311
- Metadata (title / description rules): https://support.google.com/googleplay/android-developer/answer/9898842

## What Google requires of a dating app, and where Seloze stands

| Requirement | Status |
|---|---|
| Users accept terms before creating content (all sign-up routes) | Done — required checkbox on the age gate, which every new user passes; the version + time are stored on the profile |
| Defines objectionable content and behaviour | Done — Terms §4 + Community Guidelines |
| In-app report and block, easy to find | Done — ⋮ menu on Discover cards and in chats |
| Ongoing moderation, action on reports | Automated photo/text checks + admin dashboard. **You must actually review reports promptly** |
| Age restriction (dating apps must block minors) | In-app age gate done. **Play Console switches below** |
| In-app account deletion, prominent | Done — Settings → Delete account (password/Google re-check) |
| Web page to request deletion, names the app | Done — `public/delete-account.html` (must be deployed) |
| Privacy policy linked in Play Console AND inside the app, names developer + contact, covers retention/deletion | Done — Settings → Privacy Policy; hosted page |
| Prominent in-app disclosure + affirmative tap before location permission | Done — "Use my approximate location" box, off by default |
| Data safety form matches the privacy policy | See table below |
| Store listing: no misleading claims, no ALL CAPS/emoji/keyword stuffing | Done — see `listing_copy.md` |

## Do these BEFORE you submit
1. Deploy the website pages: `firebase deploy --only hosting --project connect-dating-app-e2ad4`. Open all four in a browser: privacy, terms, guidelines, delete-account.
2. Deploy the updated cleanup function (now also deletes chat conversations): `firebase deploy --only functions:cleanupUserOnDelete --project connect-dating-app-e2ad4` (run `npm run build` in `functions/` first).
3. Delete leftover test accounts and junk profiles from the live app (the two 19 August test users and any profile with placeholder text such as "tf / hhh"), so real users never see them.
4. Create ONE reviewer account inside the app with a complete, clean profile and a photo of no real person (e.g. an illustration). You will give its email + password to Google.

## Play Console → App content (Policy and programs)
1. **Privacy policy:** `https://connect-dating-app-e2ad4.web.app/privacy.html`
2. **App access:** "All or some functionality is restricted" → add the reviewer account's email and password and short instructions ("Log in with email and password, then continue").
3. **Ads:** No (ads are switched off and the advertising-ID permissions are removed).
4. **Target audience and content:** choose **18 and over** as the ONLY age group. Then tick **Restrict minor access** (required for dating apps). Google will hide the app from people it determines are under 18.
5. **Content rating (IARC questionnaire):** answer honestly. Expect: users can interact and share content, users can share location, no sexual content in the app itself. Dating apps typically receive a high (adult) rating; that is normal.
6. **Data safety** (below). Add the deletion link: `https://connect-dating-app-e2ad4.web.app/delete-account.html` and say the app offers in-app deletion.
7. **Government / Financial features / Health / News:** No.
8. **Advertising ID:** the permission has been removed, so answer accordingly (if the form still detects it, re-check the built app bundle).

## Data safety form (answer to match the Privacy Policy)
"Shared" below follows Google's definition: sending data to a service provider that processes it for you (Google Firebase / Google Cloud) is **not** "sharing" — confirm against the form's help text when you fill it in. Data shown to other members is part of how the app works.

| Category → type | Collected | Optional? | Purposes |
|---|---|---|---|
| Personal info → Name | Yes | No | App functionality, Account management |
| Personal info → Email address | Yes | Only if you use phone sign-in | App functionality, Account management |
| Personal info → Phone number | Yes (phone sign-in) | Yes | Account management |
| Personal info → User IDs | Yes | No | App functionality, Account management |
| Personal info → Sexual orientation | Yes (who you want to see) | Yes | App functionality (filtering) — never advertising |
| Personal info → Other info (date of birth, gender, bio, profession, education, interests) | Yes | Some optional | App functionality |
| Location → Approximate location | Yes | Yes (opt-in) | App functionality |
| Photos and videos → Photos | Yes | No (at least one) | App functionality |
| Messages → Other in-app messages | Yes | No | App functionality |
| App activity → App interactions | Yes | No | App functionality, Analytics |
| App activity → Other user-generated content | Yes | No | App functionality |
| Device or other IDs | Yes (push token, Firebase installation ID) | No | App functionality, Analytics |

- **Data encrypted in transit:** Yes.
- **Users can request data deletion:** Yes — in-app, and via the web link above.
- **Financial info:** none today; add "Purchase history" when subscriptions go live.

## Store presence
- **Main store listing:** copy from `listing_copy.md` (name, short + full description). Icon `graphics/hires_icon_512.png`, feature graphic `graphics/feature_graphic_1024x500.png`.
- **Screenshots:** do NOT upload `04_paywall.png` (it shows prices for plans that are not on sale). Retake all screenshots from the current build before publishing, using only images you have the right to use.
- **Category:** Dating. **Contact email:** the one in the Privacy Policy.
- **Countries / regions:** start with India only, then add countries one by one. Some countries restrict or ban dating apps, and each region adds its own privacy rules. If you distribute in the EU, Google also requires you to declare trader status (name, address, phone, email shown on your listing).

## Testing before production
A personal developer account created after November 2023 must first run a **closed test with at least 12 testers opted in for 14 consecutive days**. Check your account type in Play Console → Developer account.

## Keep doing after launch
- Review reports and act on them quickly; keep a record of actions taken.
- Update the Privacy Policy, Data safety form and this checklist before you switch on ads or paid plans (then also remove the `tools:node="remove"` permission lines in `AndroidManifest.xml`).
- Add a named grievance/contact officer if you launch in India at scale (India's IT rules expect one), and replace the personal email with a role address on your own domain when you have one.

## Regenerating the website pages
`node tool/build_legal_pages.js` rebuilds `privacy.html`, `terms.html` and `guidelines.html` from `lib/core/constants/legal_content.dart`, so the app and website text never drift apart.
