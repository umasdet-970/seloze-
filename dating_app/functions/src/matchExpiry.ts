import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

/**
 * "First move" urgency (spec: Bumble-style) — a match that nobody has
 * messaged in within MATCH_EXPIRY_HOURS quietly expires: removed from both
 * sides' Matches list, so a match isn't a permanent, low-stakes fixture —
 * saying hi has a deadline, same reasoning Bumble's whole viral hook is
 * built on. Deliberately not gendered ("she messages first"): either side
 * sending anything keeps the match alive, which fits this app's inclusive
 * gender model (see AppUser/onboarding) better than a one-sided rule would.
 *
 * A match is two docs (users/{uid}/matches/{otherId} on each side) — only
 * processed from the lexicographically-smaller uid so each pair is handled
 * once, not twice.
 */
const MATCH_EXPIRY_HOURS = 24;
const PAGE_SIZE = 500;

export const expireStaleMatches = onSchedule(
  { schedule: "0 * * * *", timeZone: "Asia/Kolkata", timeoutSeconds: 300, memory: "256MiB" },
  async () => {
    const db = admin.firestore();
    const { Timestamp, FieldValue } = admin.firestore;
    const now = Date.now();
    const cutoff = Timestamp.fromMillis(now - MATCH_EXPIRY_HOURS * 60 * 60 * 1000);

    const stale = await db.collectionGroup("matches").where("matchedAt", "<", cutoff).limit(PAGE_SIZE).get();

    let expired = 0;
    let skippedHasMessages = 0;
    for (const doc of stale.docs) {
      const parent = doc.ref.parent.parent;
      if (!parent) continue; // shouldn't happen — matches is always a users/{uid} subcollection
      const uid = parent.id;
      const otherId = doc.id;
      if (uid >= otherId) continue; // the other side's copy of this same match handles it

      const conversationId = [uid, otherId].sort().join("_");
      const hasMessages = !(
        await db.collection("conversations").doc(conversationId).collection("messages").limit(1).get()
      ).empty;
      if (hasMessages) {
        skippedHasMessages++;
        continue; // someone said hi — no longer eligible to expire
      }

      await Promise.all([
        db.collection("users").doc(uid).collection("matches").doc(otherId).delete(),
        db.collection("users").doc(otherId).collection("matches").doc(uid).delete(),
        db.collection("conversations").doc(conversationId).delete(),
        db
          .collection("users")
          .doc(uid)
          .collection("notifications")
          .add({
            type: "matchExpired",
            title: "A match said goodbye",
            body: "Neither of you said hi in time, so that match has expired.",
            createdAt: FieldValue.serverTimestamp(),
            read: false,
          }),
        db
          .collection("users")
          .doc(otherId)
          .collection("notifications")
          .add({
            type: "matchExpired",
            title: "A match said goodbye",
            body: "Neither of you said hi in time, so that match has expired.",
            createdAt: FieldValue.serverTimestamp(),
            read: false,
          }),
      ]);
      expired++;
    }

    logger.info("Match expiry run finished", { scanned: stale.size, expired, skippedHasMessages });
  }
);
