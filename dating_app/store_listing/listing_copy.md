# Play Store listing copy

Kept here as the source of truth for what gets pasted into Play Console.
Update this file first, then copy into the console by hand.

Dating apps get extra scrutiny on Google Play. Rules followed below: no
misleading claims (nothing says profiles are "verified" — verification is a
request), no ALL-CAPS headings or emoji/keyword stuffing, nothing that
promotes casual sexual encounters, and an honest note about location use.

## App name (max 30 characters)
Seloze-Global Dating App

(24 characters — final name, chosen by the owner.) This is what people see
in Play Store search and on the listing page. The name under the icon on the
phone's home screen is separate (`android:label` in AndroidManifest.xml) and
stays "Seloze".

## Short description (max 80 characters)
Meet people worldwide. Swipe, match and chat in a safe, simple dating app.

## Full description (max 4000 characters — paste as plain text)

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

<!-- RESTORE when real billing (RevenueCat + Play subscriptions) goes live —
     do not publish this while the app cannot actually sell subscriptions:

Go Premium
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

Redeploy hosting (`firebase deploy --only hosting --project connect-dating-app-e2ad4`)
after any change to `public/`, then open all three URLs in a browser first —
Play review fails if any of them 404s.
