/// Legal documents shown inside the app. The same text is published on the
/// website (`public/privacy.html`, `public/terms.html`,
/// `public/guidelines.html`) — change both together.
///
/// Written against what the app actually does and Google Play's Developer
/// Program Policies for dating / user-generated-content apps. Dating apps are
/// held to a high standard and each country adds its own rules (GDPR, India's
/// DPDP Act, CCPA, ...), so have a qualified lawyer review these before
/// launching in each region. (That reminder lives here, not in the UI.)
///
/// Headings are marked with a leading '## '; the legal document screen
/// parses that into styled section titles.
library;

/// Bump when the Terms / Guidelines change in a way users must re-accept.
/// Stored on the user's profile next to `termsAcceptedAt`.
const String kTermsVersion = '2026-09-21';

const String kPrivacyPolicyText = '''
Last updated: 21 September 2026

## 1. Who we are
Seloze ("we", "us"), listed on Google Play as "Seloze-Global Dating App", is an international dating app operated by an individual developer based in India (the developer named on our Google Play listing). This policy explains what personal data we collect, why, who can see it, and the choices you have. You can reach us at umamaheswar.sdet@gmail.com.

## 2. What we collect
- Account data: your email address or phone number, identifiers from the sign-in provider (for example Google) if you use one, and the date you accepted our Terms.
- Profile data: name, date of birth (used to confirm you are 18 or over; it is not shown on your profile), gender, bio, profession, education, interests, city and country, and your photos.
- Preference data: who you want to see (for example men, women, or everyone), your age range and distance settings, and your dating intention and relationship preference. Depending on your choices, this can reveal information about your sexual orientation, which is sensitive personal data. Providing it is your choice. We use it only to run the app (for example, to filter who you see), and never for advertising.
- Approximate location: only if you switch on "Use my approximate location" in your profile and allow it in your device's permission prompt. We store your device's approximate location, rounded to roughly 1 km, and use it to show how far away other members are. Other members see an approximate distance, not a map or your address. You can turn this off in your profile or in your device settings at any time.
- Activity data: likes, passes, matches, messages and photos you send, reports you make or that are made about you, and how you use the app (for example, screens viewed and features used).
- Device data: device type, app version, and a push-notification token so we can send you notifications.
- Payment data (when paid plans are available): your plan and billing status from Google Play. We do not receive your card details.

## 3. How we use it
- To create and run your profile, show you to other members, and provide matching and messaging.
- To keep members safe: we automatically check photos and text for nudity, abuse and spam using Google Cloud services, handle blocks and reports, and look for fake accounts and fraud. If a check wrongly blocks your content, contact us and we will review it.
- To send you notifications about matches, likes, messages and occasional reminders. You can turn these off in Settings → Notifications. We may still send essential account and security notices.
- To understand and improve the app using usage and diagnostic data.
Where laws such as the EU or UK GDPR apply, our legal bases are: performing our contract with you; your consent (for location and for sensitive preference data, which you can withdraw by changing your settings or deleting your account); our legitimate interests in safety, fraud prevention and improving the app; and legal obligations.

## 4. Who we share it with
- Other members: your profile details (such as name, age, gender, bio, photos, interests, city, and approximate distance). We do not show your email address, phone number or date of birth.
- Service providers that process data for us: Google (Firebase for sign-in, database, file storage, push notifications and analytics; Google Cloud for automated photo and text checks). When paid plans launch, Google Play and RevenueCat will process purchase data.
- Authorities and others where required by law, or to protect the safety of our members or others.
We do not sell your personal data. We do not currently show ads; if we add them, we will update this policy first.

## 5. How long we keep it
We keep your data while your account is active. When you delete your account (Settings → Delete account), we delete your profile, photos, likes, matches, blocks, preferences, notifications, and your conversations. You can also ask us to delete your account by email (see our deletion page); we complete those requests within 30 days. We may keep limited records where needed for safety, fraud prevention or legal reasons, for example reports made about an account. Usage analytics processed by Google are kept under Google's own retention settings.

## 6. Your rights
Depending on where you live (for example under the EU or UK GDPR, India's Digital Personal Data Protection Act, or California law), you may have the right to access, correct, delete or export your data, to object to or restrict certain processing, to withdraw consent, and to complain to your local data protection authority. You can edit your profile and preferences in the app and delete your account in Settings → Delete account. For anything else, write to umamaheswar.sdet@gmail.com and we will respond as required by applicable law.

## 7. Age requirement
Seloze is only for people aged 18 or over. We ask for your date of birth when you sign up and do not let anyone under 18 continue. If we learn that a member is under 18, we will remove their account and data.

## 8. International transfers
Seloze is used in many countries, and our providers may process data in countries other than yours, including the United States. Where the law requires it, we rely on safeguards offered by our providers, such as standard contractual clauses.

## 9. Security
We use encryption in transit, access controls and automated moderation to protect your data. No system is perfectly secure. If a breach affects your data, we will notify you and the authorities where the law requires.

## 10. Changes to this policy
We will tell you in the app before material changes take effect.

## 11. Contact and complaints
umamaheswar.sdet@gmail.com
''';

const String kTermsText = '''
Last updated: 21 September 2026

## 1. Acceptance of terms
By creating a Seloze account, you agree to these Terms & Conditions, our Privacy Policy and our Community Guidelines, which together form your agreement with us. If you don't agree, don't use the app.

## 2. Eligibility
Seloze is only for people aged 18 or over. You must also be legally able to enter into a binding contract in your country, and not be barred from using an app like this by any law that applies to you. You confirm that the information you give us, including your date of birth, is accurate. If we learn that you are under 18 or gave a false date of birth, we will remove your account.

## 3. Your account
Keep your login details secure. You are responsible for everything that happens on your account, and you may only have one account. Tell us straight away if you think someone else has accessed it.

## 4. Community rules
Everyone on Seloze must follow our Community Guidelines (Settings → Community Guidelines). In short, you must not:
- Create a fake profile, impersonate someone else, or misrepresent your age, identity or intentions.
- Post nudity or sexually explicit content, or send unwanted sexual messages or images.
- Harass, threaten, stalk, bully or abuse other members, or promote hatred or discrimination.
- Involve anyone under 18 in any way.
- Ask for money, run scams, sell goods or services, offer sexual services, spam, or promote other platforms.
- Break the law, or share other people's private information or photos without their permission.
- Use bots, scrapers or other automated tools to access or interact with the app.

## 5. Reporting, moderation and enforcement
You can report or block any member from their profile menu or from a chat. We use automated checks and human review to find content and behaviour that breaks these Terms or the Community Guidelines, and we review reports. If something is broken, we may remove content, restrict features, warn you, suspend your account, or permanently ban it, and where the law requires or to protect people we may tell the authorities. If you think we made a mistake, write to us at the address below and we will look again.

## 6. Content you post
You keep ownership of the photos, bio and messages you post, but you give us a licence to host, display and transmit that content as needed to run the app (for example, showing your profile to other members). You are responsible for what you post and must have the right to post it. We may remove content that breaks these Terms.

## 7. Paid features
Seloze is free to use at the moment. If we introduce paid plans, the price, billing period and renewal terms will be shown clearly before you buy. Purchases will be handled by Google Play, so its terms and refund policies apply and you will be able to manage or cancel subscriptions in your Google Play account. Free features that have daily limits (for example, the number of profile discoveries a day) may change.

## 8. Safety when meeting people
Seloze provides tools to block and report other members, but we cannot guarantee the conduct of other members, on or off the app, and you are responsible for your own interactions with them. Meet new people safely: video chat before meeting in person, meet in public places, and tell a friend your plans. We do not run criminal background checks on members, so please use your own judgment and take care when sharing personal details.

## 9. Ending your account
You can delete your account at any time in Settings → Delete account, or by asking us through the deletion page on our website. We may suspend or terminate your account for breaking these Terms, for fraud, or to comply with the law. What happens to your data is explained in the Privacy Policy.

## 10. Disclaimers and liability
Seloze is provided "as is". We do not guarantee matches, relationships or any outcome from using the app. To the extent the law allows, our liability to you is limited to the amount you paid us in the 12 months before a claim arose. Nothing in these Terms limits any right you have under the law that cannot be excluded.

## 11. Governing law
These Terms are governed by the laws of India, without regard to conflict-of-law principles, except where local consumer protection law requires otherwise.

## 12. Changes to these Terms
We may update these Terms. We will tell you in the app before material changes take effect, and continuing to use Seloze after that means you accept the updated Terms.

## 13. Contact and complaints
umamaheswar.sdet@gmail.com
''';

const String kGuidelinesText = '''
Last updated: 21 September 2026

## Our promise
Seloze is for meeting people safely and respectfully. These guidelines explain what is and isn't allowed. They apply to your profile, photos, bio, messages and behaviour, including behaviour off the app that affects other members.

## 1. Be real
- Use your own photos, name and age. No fake profiles, impersonation or "catfishing".
- Do not pretend to be someone you are not, and do not create more than one account.

## 2. Adults only
- You must be 18 or over. Never post photos of, or send messages involving, anyone under 18.
- We remove accounts that appear to belong to a minor. Content that sexualises minors is reported to the authorities.

## 3. Keep it appropriate
- No nudity or sexually explicit photos, in your profile or in chat.
- No sexual harassment: do not send unwanted sexual messages, images or requests.
- Photos and text are checked automatically, and content that breaks these rules may be blocked.

## 4. Treat people with respect
- No harassment, bullying, stalking, threats or intimidation.
- No hate speech or discrimination based on race, ethnicity, religion, caste, gender, sexual orientation, disability or similar.
- Respect a "no". If someone stops replying, unmatches or blocks you, leave them alone.

## 5. No scams, selling or spam
- Do not ask for money, gifts, bank or card details, and do not run investment, crypto or romance-scam schemes.
- Do not advertise or sell products or services, recruit for a business, or promote other apps or accounts.
- No offers of escort, prostitution or other sexual services.
- No spam, bots or automated messages.

## 6. Stay legal and protect privacy
- Nothing illegal, and no promotion of violence, self-harm, weapons or drugs.
- Do not share other people's private information or photos without their permission.

## 7. Reporting and blocking
- To report or block someone, open the menu on their profile card in Discover, or the menu in your chat with them.
- After you block someone, they no longer appear to you and you no longer appear to them.
- Reports are reviewed by our team, and we take action where these guidelines are broken.

## 8. What happens if the rules are broken
Depending on how serious it is, we may remove content, send a warning, suspend the account for a while, or ban it permanently. Serious cases may be reported to the authorities. If you think we got it wrong, email us and we will look again.

## 9. Meeting in person
- Chat and video call first, and trust your instincts.
- Meet in a public place and tell a friend or family member where you are going.
- Arrange your own transport, and do not share your home address, financial details or other sensitive information early on.
- We do not run criminal background checks on members.

## 10. In an emergency
If you are in immediate danger, contact your local emergency services first. Seloze cannot respond to emergencies.

## Contact
umamaheswar.sdet@gmail.com
''';
