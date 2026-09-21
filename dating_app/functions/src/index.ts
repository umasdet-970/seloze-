import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as functionsV1 from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

export { moderateImage, moderateText } from "./moderation";
export { revenueCatWebhook } from "./revenuecat_webhook";
export { creditReferralOnProfileComplete } from "./referrals";
export { sendReengagementPush } from "./reengagement";

/**
 * Push delivery (spec section 13). The mobile app's PushNotificationService
 * (lib/data/repositories/firebase/push_notification_service.dart) already
 * registers each signed-in device's FCM token onto `users/{uid}/private/account`,
 * and every event (new like, match, message, etc. — see
 * NotificationRepository on the client) writes an in-app record to
 * `users/{uid}/notifications/{id}` with {type, title, body, createdAt, read}.
 *
 * Before this function existed, that was the whole story: tokens were
 * being collected and in-app records written, but nothing ever called the
 * FCM Admin SDK, so no device ever actually received a push. This
 * function is that missing half — it watches for those doc creates and
 * sends.
 */
export const sendPushOnNotificationCreate = onDocumentCreated(
  "users/{uid}/notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const uid = event.params.uid;
    const notification = snapshot.data();

    // Push tokens live in the owner-only `private/account` doc. Accounts that
    // haven't opened the updated app yet still have them on the public profile
    // doc, so fall back to that until the client migrates them.
    const db = admin.firestore();
    const accountRef = db.collection("users").doc(uid).collection("private").doc("account");
    const [accountDoc, userDoc] = await Promise.all([
      accountRef.get(),
      db.collection("users").doc(uid).get(),
    ]);
    const accountTokens: string[] = accountDoc.data()?.fcmTokens ?? [];
    const legacyTokens: string[] = userDoc.data()?.fcmTokens ?? [];
    const tokens = Array.from(new Set([...accountTokens, ...legacyTokens]));
    if (tokens.length === 0) {
      logger.info(`No FCM tokens for ${uid}, skipping push`, { uid });
      return;
    }

    const title = (notification?.title as string | undefined) ?? "Seloze";
    const body = (notification?.body as string | undefined) ?? "";

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        type: (notification?.type as string | undefined) ?? "",
        notificationId: event.params.notificationId,
      },
    });

    // Prune tokens the client already lost (app uninstalled, data
    // cleared, etc.) so `fcmTokens` doesn't grow unbounded with dead
    // entries — FCM returns specific error codes for these, letting us
    // tell "gone for good" apart from "transient failure, leave it".
    const deadTokens: string[] = [];
    response.responses.forEach((r, i) => {
      const code = r.error?.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        deadTokens.push(tokens[i]);
      }
    });
    if (deadTokens.length > 0) {
      const remove = admin.firestore.FieldValue.arrayRemove(...deadTokens);
      // `set(..., merge)` so a missing account doc doesn't fail the prune.
      await accountRef.set({ fcmTokens: remove }, { merge: true });
      if (legacyTokens.length > 0) {
        await db.collection("users").doc(uid).update({ fcmTokens: remove });
      }
      logger.info(`Removed ${deadTokens.length} dead FCM token(s) for ${uid}`, { uid });
    }
  }
);

/**
 * Account-deletion cleanup (spec section 14/20). `AuthRepository.deleteAccount()`
 * (client, firebase_auth_repository.dart) deletes the Firebase Auth user
 * and the `users/{uid}` root doc, but Firestore never cascade-deletes
 * subcollections — without this function, `users/{uid}/matches`,
 * `/swipes`, `/likesReceived`, `/blocked`, `/reported`, `/notifications`
 * and `/private` would all sit orphaned forever under a uid no account
 * owns anymore.
 *
 * Also cleans up OTHER users' stale references to the deleted uid — a
 * former match partner's own `matches/{deletedUid}` doc, and anyone whose
 * `likesReceived/{deletedUid}` is still pending. Both subcollections
 * carry a denormalized `otherUserId`/`fromUserId` field precisely so a
 * collection-group query can find these across every user (Firestore
 * can't filter a collection-group query on document ID directly) — see
 * FirestoreSocialRepository's schema comment. `conversations/*` docs and
 * their messages are deliberately left alone: chat_providers.dart derives
 * the visible conversation list FROM the matches list, so once a match
 * doc is gone, the conversation simply stops appearing in that user's
 * chat list — no separate cleanup needed there, and the message history
 * itself isn't harmful to leave orphaned. `blocked`/`reported`
 * cross-references are also deliberately left alone: harmless (already
 * filtered out client-side when the referenced profile fails to load —
 * see `blockedProfilesProvider`) and, for `reported` specifically,
 * worth preserving as a moderation record even after the account is gone.
 *
 * Uses the v1 SDK for this trigger specifically — as of the
 * firebase-functions version pinned in package.json, `auth.user().onDelete()`
 * (a genuine "after the fact" trigger, distinct from v2's
 * beforeUserDeleted blocking trigger) is still v1-only.
 */
export const cleanupUserOnDelete = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const userRef = admin.firestore().collection("users").doc(uid);

  // Every step runs even if an earlier one throws — a failure in (say) the
  // cross-user sweep must never leave the deleted user's own data or photos
  // behind. Failures are collected and reported together at the end.
  const failures: string[] = [];
  const step = async (label: string, fn: () => Promise<unknown>) => {
    try {
      await fn();
    } catch (err) {
      failures.push(label);
      logger.error(`cleanupUserOnDelete: step "${label}" failed for ${uid}`, { uid, err });
    }
  };

  const subcollections = [
    "private",
    "swipes",
    "likesReceived",
    "matches",
    "blocked",
    "reported",
    "notifications",
  ];
  for (const name of subcollections) {
    await step(`subcollection ${name}`, () => deleteCollection(userRef.collection(name), 200));
  }

  // Chat conversations the user took part in, with all their messages
  // (`conversations/{id}` carries a `participants` array). They were left
  // behind before, so "delete my account" did not delete what people had
  // written. The other person already stops seeing the conversation once
  // the match doc is gone (see the doc comment above), so removing the
  // whole thing loses them nothing they could still open.
  await step("conversations", async () => {
    const db = admin.firestore();
    const convos = await db.collection("conversations").where("participants", "array-contains", uid).get();
    for (const convo of convos.docs) {
      await db.recursiveDelete(convo.ref);
    }
  });

  // The root doc itself, in case deleteAccount()'s client-side delete
  // didn't run (e.g. the auth user was removed directly from the
  // console, or the client delete failed after the auth delete
  // succeeded but before the Firestore delete did).
  await step("root doc", () => userRef.delete());

  // Profile photos (see FirebaseStorageUploader: profile_photos/{uid}/...).
  // Firestore cleanup alone left every uploaded photo in the bucket,
  // readable by any signed-in user, after the account was deleted.
  await step("profile photos", () =>
    admin.storage().bucket().deleteFiles({ prefix: `profile_photos/${uid}/`, force: true })
  );

  let staleMatches = 0;
  let stalePendingLikes = 0;
  await step("stale matches in other users", async () => {
    staleMatches = await deleteCollectionGroupWhere("matches", "otherUserId", uid, 200);
  });
  await step("stale pending likes in other users", async () => {
    stalePendingLikes = await deleteCollectionGroupWhere("likesReceived", "fromUserId", uid, 200);
  });

  logger.info(
    `Cleaned up data for deleted user ${uid}: ` +
      `${staleMatches} stale match reference(s), ${stalePendingLikes} stale pending like(s), ` +
      `${failures.length} failed step(s)`,
    { uid, staleMatches, stalePendingLikes, failures }
  );

  // Throwing after every step has been attempted marks the invocation as
  // failed in the Cloud Functions dashboard/alerts without skipping work.
  if (failures.length > 0) {
    throw new Error(`cleanupUserOnDelete incomplete for ${uid}: ${failures.join(", ")}`);
  }
});

async function deleteCollection(
  collectionRef: admin.firestore.CollectionReference,
  batchSize: number
): Promise<void> {
  const snapshot = await collectionRef.limit(batchSize).get();
  if (snapshot.empty) return;

  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  if (snapshot.size === batchSize) {
    // More docs than fit in one batch — recurse until the collection is
    // empty rather than assuming one page is everything.
    await deleteCollection(collectionRef, batchSize);
  }
}

/**
 * Deletes every document across ALL users' subcollections named
 * `collectionGroupName` where `field == value` — e.g. every `matches`
 * doc (under any user) with `otherUserId == <deletedUid>`. Requires a
 * collection-group index on (collectionGroupName, field) — see
 * firestore.indexes.json. Returns the number of documents deleted, for
 * logging.
 */
async function deleteCollectionGroupWhere(
  collectionGroupName: string,
  field: string,
  value: string,
  batchSize: number
): Promise<number> {
  let deleted = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snapshot = await admin
      .firestore()
      .collectionGroup(collectionGroupName)
      .where(field, "==", value)
      .limit(batchSize)
      .get();
    if (snapshot.empty) break;

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.size;

    if (snapshot.size < batchSize) break;
  }
  return deleted;
}
