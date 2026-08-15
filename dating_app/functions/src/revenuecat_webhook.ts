import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

/**
 * LTV data plumbing (spec section 17). RevenueCat is the source of
 * truth for real transaction history — client-side
 * `RevenueCatBillingRepository` only ever sees the CURRENT entitlement
 * state on the device that's open, never the full purchase/renewal/
 * cancellation history (see that file's doc comment). RevenueCat can
 * push that history to this endpoint as webhooks; this function just
 * records what it receives into `revenueCatEvents/{eventId}`, which
 * `FirestoreAdminRepository.growthMetrics()` (admin_dashboard) reads to
 * compute real average revenue-per-paying-user.
 *
 * Requires, once you have a RevenueCat account (see BILLING_SETUP.md):
 * 1. Deploy this function, note its URL (`firebase deploy --only functions`
 *    prints it, or find it in the Firebase console → Functions).
 * 2. RevenueCat dashboard → Project settings → Integrations → Webhooks →
 *    add this URL, and set an Authorization header value of your
 *    choosing.
 * 3. Set that same value as this function's secret:
 *    `firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET`
 *    then redeploy.
 *
 * Never actually invoked or tested against a real RevenueCat account —
 * written and reviewed by hand, matching RevenueCat's documented webhook
 * payload shape (event.type/app_user_id/price_in_purchased_currency/
 * event_timestamp_ms/product_id/id), same Node.js-not-installed caveat
 * as the rest of `functions/`.
 */
const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

// Event types that represent realized revenue — CANCELLATION/EXPIRATION/
// BILLING_ISSUE etc. are recorded for completeness (useful for churn
// analysis later) but excluded from the revenue sum computed on the
// read side, via their `revenueUsd` staying 0.
const _REVENUE_EVENT_TYPES = new Set(["INITIAL_PURCHASE", "RENEWAL", "NON_RENEWING_PURCHASE"]);

export const revenueCatWebhook = onRequest({ secrets: [revenueCatWebhookSecret] }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  const providedAuth = req.headers.authorization;
  if (!providedAuth || providedAuth !== revenueCatWebhookSecret.value()) {
    logger.warn("revenueCatWebhook: rejected request with invalid/missing Authorization header");
    res.status(401).send("Unauthorized");
    return;
  }

  const event = req.body?.event;
  if (!event || typeof event !== "object") {
    res.status(400).send("Missing event payload");
    return;
  }

  const eventId = event.id as string | undefined;
  const uid = event.app_user_id as string | undefined;
  const type = (event.type as string | undefined) ?? "UNKNOWN";
  if (!eventId || !uid) {
    res.status(400).send("Missing event.id or event.app_user_id");
    return;
  }

  const revenueUsd = _REVENUE_EVENT_TYPES.has(type)
    ? (event.price_in_purchased_currency as number | undefined) ?? (event.price as number | undefined) ?? 0
    : 0;

  try {
    // Doc ID = RevenueCat's own event id, so a webhook retry (RevenueCat
    // retries on non-2xx or timeout) overwrites the same doc instead of
    // double-counting revenue.
    await admin
      .firestore()
      .collection("revenueCatEvents")
      .doc(eventId)
      .set({
        uid,
        type,
        productId: event.product_id ?? null,
        revenueUsd,
        currency: event.currency ?? null,
        eventTimestampMs: event.event_timestamp_ms ?? null,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    res.status(200).send("OK");
  } catch (error) {
    logger.error("revenueCatWebhook: failed to record event", error);
    // 500 tells RevenueCat to retry — this really was a transient
    // failure on our end (Firestore write), not a bad payload.
    res.status(500).send("Internal error");
  }
});
