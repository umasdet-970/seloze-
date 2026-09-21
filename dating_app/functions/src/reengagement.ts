import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {
  Candidate,
  DAY_MS,
  MAX_INACTIVE_DAYS,
  MIN_INACTIVE_DAYS,
  RESULT_WINDOW_DAYS,
  pickMessage,
  reengagementGroup,
  returnedAfter,
  skipReason,
  summarize,
} from "./reengagement_logic";

/**
 * Daily "come back" push for people who have gone quiet.
 *
 * Every evening (7 pm IST) this finds users inactive for 2–14 days and sends
 * ONE short, truthful push (someone liked you / new people joined / fresh
 * profiles), at most once every 3 days, only to people whose Notification
 * settings → Promotional switch is on. It delivers by writing a
 * users/{uid}/notifications doc, which sendPushOnNotificationCreate turns
 * into a push (and prunes dead tokens).
 *
 * 10% of eligible people are deliberately held out (never pushed). A week
 * after each person is first evaluated, we check whether they came back
 * (lastActiveAt moved). Comparing the two groups is the proof of whether
 * the push helps — see reengagementSummary/latest and the run log.
 *
 * Bookkeeping lives in `reengagement/{uid}` and `reengagementSummary/latest`,
 * both written only by this function (firestore.rules: admin read only).
 */
const PAGE_SIZE = 300;
const MAX_USERS_PER_RUN = 5000;
const CONCURRENCY = 20;

export const sendReengagementPush = onSchedule(
  { schedule: "0 19 * * *", timeZone: "Asia/Kolkata", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const db = admin.firestore();
    const { Timestamp, FieldValue } = admin.firestore;
    const now = Date.now();

    // 1. Score people evaluated a week ago (also feeds the summary below).
    await recordResults(db, now);

    // 2. Push to today's eligible people.
    const newPeopleThisWeek = (
      await db
        .collection("users")
        .where("createdAt", ">=", Timestamp.fromMillis(now - 7 * DAY_MS))
        .count()
        .get()
    ).data().count;

    const counts: Record<string, number> = {
      scanned: 0,
      sent: 0,
      holdout: 0,
      incomplete: 0,
      "inactive-account": 0,
      "no-token": 0,
      "opted-out": 0,
      "too-soon": 0,
    };

    const inactiveFrom = Timestamp.fromMillis(now - MAX_INACTIVE_DAYS * DAY_MS);
    const inactiveUntil = Timestamp.fromMillis(now - MIN_INACTIVE_DAYS * DAY_MS);
    let cursor: admin.firestore.QueryDocumentSnapshot | undefined;

    while (counts.scanned < MAX_USERS_PER_RUN) {
      let query = db
        .collection("users")
        .where("lastActiveAt", ">=", inactiveFrom)
        .where("lastActiveAt", "<", inactiveUntil)
        .orderBy("lastActiveAt")
        .limit(PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);

      const page = await query.get();
      if (page.empty) break;
      cursor = page.docs[page.docs.length - 1];
      counts.scanned += page.size;

      const [reSnaps, settingsSnaps] = await Promise.all([
        db.getAll(...page.docs.map((d) => db.collection("reengagement").doc(d.id))),
        db.getAll(...page.docs.map((d) => d.ref.collection("private").doc("settings"))),
      ]);

      for (let i = 0; i < page.docs.length; i += CONCURRENCY) {
        await Promise.all(
          page.docs.slice(i, i + CONCURRENCY).map(async (doc, j) => {
            const reSnap = reSnaps[i + j];
            const data = doc.data();
            const prefs = settingsSnaps[i + j].data()?.notificationPrefs;
            const candidate: Candidate = {
              profileComplete: data.profileComplete === true,
              accountActive: (data.accountStatus ?? "active") === "active",
              hasToken: Array.isArray(data.fcmTokens) && data.fcmTokens.length > 0,
              promotionalOptIn: prefs?.promotional !== false,
              lastSentAtMs: reSnap.data()?.lastSentAt?.toMillis?.(),
            };

            const skip = skipReason(candidate, now);
            if (skip) {
              counts[skip]++;
              return;
            }

            const firstEvaluation = reSnap.exists ? {} : {
              evaluatedAt: Timestamp.fromMillis(now),
              // Checked for a return once this window has passed.
              resultDueAt: Timestamp.fromMillis(now + RESULT_WINDOW_DAYS * DAY_MS),
            };

            if (reengagementGroup(doc.id) === "holdout") {
              counts.holdout++;
              if (!reSnap.exists) await reSnap.ref.set({ group: "holdout", sends: 0, ...firstEvaluation });
              return;
            }

            const pendingLikes = (await doc.ref.collection("likesReceived").count().get()).data().count;
            const message = pickMessage({ pendingLikes, newPeopleThisWeek });

            await doc.ref.collection("notifications").add({
              type: "promotional",
              title: message.title,
              body: message.body,
              createdAt: FieldValue.serverTimestamp(),
              read: false,
            });
            await reSnap.ref.set(
              {
                group: "push",
                lastSentAt: Timestamp.fromMillis(now),
                lastKind: message.kind,
                sends: FieldValue.increment(1),
                ...firstEvaluation,
              },
              { merge: true }
            );
            counts.sent++;
          })
        );
      }
      if (page.size < PAGE_SIZE) break;
    }

    logger.info("Re-engagement push run finished", counts);
  }
);

/**
 * For everyone first evaluated at least a week ago, records whether they came
 * back, then refreshes the pushed-vs-held-out comparison.
 */
async function recordResults(db: admin.firestore.Firestore, now: number): Promise<void> {
  const { Timestamp, FieldValue } = admin.firestore;

  const due = await db
    .collection("reengagement")
    .where("resultDueAt", "<=", Timestamp.fromMillis(now))
    .limit(500)
    .get();

  for (const doc of due.docs) {
    const evaluatedAtMs = (doc.data().evaluatedAt as admin.firestore.Timestamp | undefined)?.toMillis();
    const user = await db.collection("users").doc(doc.id).get();
    const lastActiveAtMs = (user.data()?.lastActiveAt as admin.firestore.Timestamp | undefined)?.toMillis();
    await doc.ref.update({
      returned: evaluatedAtMs !== undefined && returnedAfter(lastActiveAtMs, evaluatedAtMs),
      resultRecordedAt: Timestamp.fromMillis(now),
      // Drops it out of the "due" query above so recorded people are never re-read.
      resultDueAt: FieldValue.delete(),
    });
  }

  const total = async (group: string, returned: boolean) =>
    (
      await db
        .collection("reengagement")
        .where("group", "==", group)
        .where("returned", "==", returned)
        .count()
        .get()
    ).data().count;
  const [pushYes, pushNo, holdYes, holdNo] = await Promise.all([
    total("push", true),
    total("push", false),
    total("holdout", true),
    total("holdout", false),
  ]);

  const summary = summarize(pushYes, pushYes + pushNo, holdYes, holdYes + holdNo);
  await db
    .collection("reengagementSummary")
    .doc("latest")
    .set({ ...summary, updatedAt: FieldValue.serverTimestamp() });
  logger.info("Re-engagement comparison (came back within 7 days)", summary);
}
