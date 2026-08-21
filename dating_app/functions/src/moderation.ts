import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { ImageAnnotatorClient } from "@google-cloud/vision";
import { LanguageServiceClient } from "@google-cloud/language";

const visionClient = new ImageAnnotatorClient();
const languageClient = new LanguageServiceClient();

/**
 * Real AI moderation (spec section 12/19), replacing the rule-based
 * checks in `ModerationRepository` — those stay in place client-side as
 * a fallback for when these functions are unreachable (not yet deployed,
 * network error, etc. — see `CloudModerationRepository`'s catch block),
 * not removed.
 *
 * Requires the Blaze plan (same as every other function here) PLUS the
 * Cloud Vision API and Cloud Natural Language API enabled in the GCP
 * console for this Firebase project — both are pay-per-use APIs on the
 * same billing account, no separate account signup needed beyond what
 * Cloud Functions already requires.
 */

const BLOCK_LIKELIHOODS = new Set(["LIKELY", "VERY_LIKELY"]);

interface ModerationResponse {
  allowed: boolean;
  category: "none" | "harassment" | "spam" | "contactInfoSharing";
  reason: string | null;
}

/**
 * Cloud Vision SafeSearch on a photo URL (spec: "Photo verification",
 * "Photo moderation", "Photo safety checks"). `imageUri` works for any
 * publicly fetchable HTTPS URL — including Firebase Storage download
 * URLs, which is what the app's photo upload flow produces.
 */
export const moderateImage = onCall(async (request): Promise<ModerationResponse> => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const imageUrl = request.data?.imageUrl as string | undefined;
  if (!imageUrl) {
    throw new HttpsError("invalid-argument", "imageUrl is required.");
  }

  try {
    const [result] = await visionClient.safeSearchDetection({
      image: { source: { imageUri: imageUrl } },
    });
    const safe = result.safeSearchAnnotation;
    if (!safe) {
      return { allowed: true, category: "none", reason: null };
    }

    // @google-cloud/vision types safe.adult/violence/racy as its own
    // Likelihood enum (whose members are these same string literals), not
    // plain `string` — cast so this array's type matches the runtime value.
    const checks: Array<[string, string | null | undefined]> = [
      ["adult", safe.adult as string | null | undefined],
      ["violence", safe.violence as string | null | undefined],
      ["racy", safe.racy as string | null | undefined],
    ];

    for (const [label, likelihood] of checks) {
      if (likelihood && BLOCK_LIKELIHOODS.has(likelihood)) {
        return {
          allowed: false,
          category: "spam",
          reason: `This photo was flagged for ${label} content and can't be used.`,
        };
      }
    }

    return { allowed: true, category: "none", reason: null };
  } catch (error) {
    logger.error("moderateImage failed", error);
    throw new HttpsError("internal", "Photo moderation failed.");
  }
});

/**
 * Cloud Natural Language's `moderateText` (spec: "Profile text
 * moderation", "Message safety checks"). Chosen over the Perspective API
 * mentioned in the original code comments because it authenticates with
 * the same Application Default Credentials every other function here
 * already has — Perspective API needs a separately-requested API key,
 * a whole extra manual step this avoids.
 */
const BLOCKED_TEXT_CATEGORIES: Record<string, ModerationResponse["category"]> = {
  Toxic: "harassment",
  Insult: "harassment",
  Profanity: "harassment",
  Derogatory: "harassment",
  Violent: "spam",
  Sexual: "spam",
};
const TEXT_CONFIDENCE_THRESHOLD = 0.7;

export const moderateText = onCall(async (request): Promise<ModerationResponse> => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const text = (request.data?.text as string | undefined)?.trim();
  if (!text) {
    return { allowed: true, category: "none", reason: null };
  }

  try {
    const [result] = await languageClient.moderateText({
      document: { content: text, type: "PLAIN_TEXT" },
    });

    for (const cat of result.moderationCategories ?? []) {
      const name = cat.name ?? "";
      const confidence = cat.confidence ?? 0;
      const mapped = BLOCKED_TEXT_CATEGORIES[name];
      if (mapped && confidence >= TEXT_CONFIDENCE_THRESHOLD) {
        return {
          allowed: false,
          category: mapped,
          reason: "This contains language that violates our community guidelines.",
        };
      }
    }

    return { allowed: true, category: "none", reason: null };
  } catch (error) {
    logger.error("moderateText failed", error);
    throw new HttpsError("internal", "Text moderation failed.");
  }
});
