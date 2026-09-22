import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

/**
 * Invite-a-friend rewards.
 *
 * A friend who installs Seloze through someone's invite link is recorded on
 * their own `users/{uid}.invitedBy` at sign-up (from the Play install
 * referrer). The inviter is only rewarded once that friend actually
 * completes their profile — i.e. `profileComplete` flips to true, which the
 * app only sets when a name and at least one moderated photo exist. That
 * keeps a bare email sign-up from paying out.
 *
 * Rewards live in `users/{inviter}/private/rewards.referralCount`, a doc
 * clients can READ but never write (firestore.rules) — this function, via
 * the Admin SDK, is the only writer, so nobody can give themselves a bonus.
 * The client turns the count into extra daily discoveries, capped at
 * MAX_REWARDED_FRIENDS (see lib/core/config/referral_config.dart — keep the
 * two numbers in sync).
 */
const MAX_REWARDED_FRIENDS = 5;
const BONUS_PER_FRIEND = 5;
// Coins economy (spec: Badoo-style Superpowers) — keep in sync with
// lib/core/config/wallet_config.dart's kCoinsPerReferral. Uncapped, unlike
// the discovery bonus above: coins are a spend-them-down currency (Boost/
// Rose), not a standing daily perk, so there's less reason to cap how
// many a prolific inviter can stock up.
const COINS_PER_REFERRAL = 30;

export const creditReferralOnProfileComplete = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  // Only the moment the profile becomes complete.
  if (before.profileComplete === true || after.profileComplete !== true) return;

  const inviteeId = event.params.uid;
  const inviterId = after.invitedBy;
  if (typeof inviterId !== "string" || inviterId.length === 0 || inviterId === inviteeId) return;

  const db = admin.firestore();
  // Doc id = invitee uid, so a friend can only ever be credited once, even
  // if this trigger is retried or their profile completes again later.
  const referralRef = db.collection("referrals").doc(inviteeId);
  const inviterRef = db.collection("users").doc(inviterId);
  const rewardsRef = inviterRef.collection("private").doc("rewards");
  // Same doc every other client-trust balance in this app lives in (quota,
  // ad-bonus, rose-count) — see WalletRepository's doc comment for why
  // this one doesn't need the rewards doc's server-only treatment.
  const walletRef = inviterRef.collection("private").doc("wallet");

  const result = await db.runTransaction(async (tx) => {
    const [existing, inviter, rewards] = await Promise.all([
      tx.get(referralRef),
      tx.get(inviterRef),
      tx.get(rewardsRef),
    ]);
    if (existing.exists || !inviter.exists) return null;

    const previousCount = (rewards.data()?.referralCount as number | undefined) ?? 0;
    const rewarded = previousCount < MAX_REWARDED_FRIENDS;
    tx.set(referralRef, {
      inviterId,
      inviteeId,
      rewarded,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Count every friend who joins (for the progress display); the bonus
    // itself is capped client-side at MAX_REWARDED_FRIENDS.
    tx.set(rewardsRef, { referralCount: admin.firestore.FieldValue.increment(1) }, { merge: true });
    tx.set(walletRef, { balance: admin.firestore.FieldValue.increment(COINS_PER_REFERRAL) }, { merge: true });
    return { rewarded };
  });

  if (!result) return;

  // An in-app notification; sendPushOnNotificationCreate turns it into a
  // push automatically.
  await inviterRef.collection("notifications").add({
    type: "referralReward",
    title: result.rewarded ? "A friend joined Seloze" : "Another friend joined",
    body: result.rewarded
      ? `You earned +${BONUS_PER_FRIEND} discoveries a day and ${COINS_PER_REFERRAL} coins.`
      : `Thanks for inviting friends — you've already unlocked the maximum discovery bonus, but you still earned ${COINS_PER_REFERRAL} coins.`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false,
  });

  logger.info(`Credited referral: ${inviterId} invited ${inviteeId}`, {
    inviterId,
    inviteeId,
    rewarded: result.rewarded,
  });
});
