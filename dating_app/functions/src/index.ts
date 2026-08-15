import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as functionsV1 from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

export { moderateImage, moderateText } from "./moderation";
export { revenueCatWebhook } from "./revenuecat_webhook";

/**
 * Push delivery (spec section 13). The mobile app's PushNotificationService
 * (lib/data/repositories/firebase/push_notification_service.dart) already
 * registers each signed-in device's FCM token onto `users/{uid}.fcmTokens`,
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

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const tokens: string[] = userDoc.data()?.fcmTokens ?? [];
    if (tokens.length === 0) {
      logger.info(`No FCM tokens for ${uid}, skipping push`, { uid });
      return;
    }

    const title = (notification?.title as string | undefined) ?? "Connect";
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
      await admin
        .firestore()
        .collection("users")
        .doc(uid)
        .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...deadTokens) });
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
    await deleteCollection(userRef.collection(name), 200);
  }

  // The root doc itself, in case deleteAccount()'s client-side delete
  // didn't run (e.g. the auth user was removed directly from the
  // console, or the client delete failed after the auth delete
  // succeeded but before the Firestore delete did).
  await userRef.delete().catch(() => undefined);

  const [staleMatches, stalePendingLikes] = await Promise.all([
    deleteCollectionGroupWhere("matches", "otherUserId", uid, 200),
    deleteCollectionGroupWhere("likesReceived", "fromUserId", uid, 200),
  ]);

  logger.info(
    `Cleaned up Firestore data for deleted user ${uid}: ` +
      `${staleMatches} stale match reference(s), ${stalePendingLikes} stale pending like(s)`,
    { uid, staleMatches, stalePendingLikes }
  );
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
