# Play Store listing copy — draft

Not app code; kept here as the source of truth for what gets pasted into
Play Console. Update this file first, then copy into the console by hand.

## App name (max 30 characters — Play Console rejects longer)
Seloze-Global Dating App

(24 characters — final name, chosen by the owner.)

This is the name people see in Play Store search and on the listing page.
The name under the icon on the phone's home screen is separate (the
`android:label` in AndroidManifest.xml) and stays "Seloze".

## Short description (max 80 characters, currently 73)
Swipe, match, and chat — real connections with verified profiles.

## Full description (max 4000 characters)

Seloze is a global dating app built around one idea: meeting
someone should feel safe, simple, and actually enjoyable.

**Discover people**
Swipe through profiles filtered by what you're looking for — age range,
distance, and dating intention (long-term, short-term, new friends, or
still figuring it out). Like, pass, or super-like to stand out.

**Match and start talking**
When you both like each other, it's a match — chat right away with
real-time messaging, photo sharing, and typing indicators.

**Safer profiles**
Members can request photo verification to earn a trust badge. Block and
report tools are available on every profile and every chat, and our
moderation team reviews reports to keep the community genuine.

**Stay in control**
Fine-tune who sees your profile, pause visibility anytime, and manage
notifications the way you want them. You can delete your account and data
at any time from Settings.

**Free to use**
Seloze is free, with 10 profile discoveries a day. Premium plans are coming
soon.

Seloze is intended for adults 18 and over.

<!-- RESTORE when real billing (RevenueCat + Play subscriptions) goes live —
     do not publish this while the app cannot actually sell subscriptions:

**Go Premium**
Free members get 10 profile discoveries a day. Premium unlocks 50 profile
discoveries and 50 likes a day, unlimited messaging, premium filters, and
an ad-free experience. Prefer to just remove ads? Ad-Free is available on
its own.

Premium and Ad-Free are auto-renewing subscriptions billed through Google
Play. Manage or cancel anytime in your Play Store account settings.
-->

---
Privacy Policy: https://connect-dating-app-e2ad4.web.app/privacy.html
Terms & Conditions: https://connect-dating-app-e2ad4.web.app/terms.html
Delete your account (Data safety form): https://connect-dating-app-e2ad4.web.app/delete-account.html

Note: privacy.html and terms.html are already live on Firebase Hosting.
delete-account.html is new — it only works once you run
`firebase deploy --only hosting --project connect-dating-app-e2ad4`
from the dating_app folder. Open all three URLs in a browser first;
Play review fails if any of them 404s.
