/**
 * Pure decision logic for the daily re-engagement push — no Firebase imports,
 * so it can be unit-tested directly (see functions/test/reengagement.test.js).
 */

/** Share of eligible users deliberately NOT sent a push, so their return
 *  rate can be compared with the pushed group (the "proof" of whether the
 *  push helps at all). */
export const HOLDOUT_PERCENT = 10;

/** Only people who have gone quiet: inactive at least this long... */
export const MIN_INACTIVE_DAYS = 2;
/** ...but not so long that they've almost certainly uninstalled. */
export const MAX_INACTIVE_DAYS = 14;
/** Never push the same person more often than this. */
export const MIN_DAYS_BETWEEN_PUSHES = 3;
/** How long after we first evaluate someone we wait before checking
 *  whether they came back. */
export const RESULT_WINDOW_DAYS = 7;

export const DAY_MS = 24 * 60 * 60 * 1000;

export type Group = "holdout" | "push";

/**
 * Stable per-user assignment (FNV-1a hash of the uid), so the same person is
 * always in the same group on every run and the comparison stays valid.
 */
export function reengagementGroup(uid: string): Group {
  let h = 2166136261;
  for (let i = 0; i < uid.length; i++) {
    h ^= uid.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h % 100 < HOLDOUT_PERCENT ? "holdout" : "push";
}

export interface Candidate {
  /** users/{uid}.profileComplete === true */
  profileComplete: boolean;
  /** users/{uid}.accountStatus is missing or "active" */
  accountActive: boolean;
  /** has at least one FCM token (i.e. can receive a push) */
  hasToken: boolean;
  /** Notification settings → Promotional switch (defaults to on). */
  promotionalOptIn: boolean;
  /** When we last pushed this person, if ever. */
  lastSentAtMs?: number;
}

export type SkipReason = "incomplete" | "inactive-account" | "no-token" | "opted-out" | "too-soon";

/** Returns null when this person may be pushed, otherwise why not. */
export function skipReason(c: Candidate, nowMs: number): SkipReason | null {
  if (!c.profileComplete) return "incomplete";
  if (!c.accountActive) return "inactive-account";
  if (!c.promotionalOptIn) return "opted-out";
  if (!c.hasToken) return "no-token";
  if (c.lastSentAtMs !== undefined && nowMs - c.lastSentAtMs < MIN_DAYS_BETWEEN_PUSHES * DAY_MS) {
    return "too-soon";
  }
  return null;
}

export interface Facts {
  /** People who have liked this user and are still waiting. */
  pendingLikes: number;
  /** New sign-ups platform-wide in the last 7 days. */
  newPeopleThisWeek: number;
}

export type MessageKind = "likes" | "new_people" | "generic";

export interface Message {
  kind: MessageKind;
  title: string;
  body: string;
}

/** Picks the most compelling true statement we can make to this person. */
export function pickMessage(f: Facts): Message {
  if (f.pendingLikes > 0) {
    return {
      kind: "likes",
      title: "Someone likes you",
      body:
        f.pendingLikes === 1
          ? "1 person liked your profile. Open Seloze to see."
          : `${f.pendingLikes} people liked your profile. Open Seloze to see.`,
    };
  }
  if (f.newPeopleThisWeek >= 5) {
    return {
      kind: "new_people",
      title: "New people on Seloze",
      body: `${f.newPeopleThisWeek} new people joined this week. Come take a look.`,
    };
  }
  return {
    kind: "generic",
    title: "Your discoveries are waiting",
    body: "Come back for today's fresh profiles.",
  };
}

/** Did the person return after we evaluated them? (They were inactive at
 *  evaluation time, so any later activity means they came back.) */
export function returnedAfter(lastActiveAtMs: number | undefined, evaluatedAtMs: number): boolean {
  return lastActiveAtMs !== undefined && lastActiveAtMs > evaluatedAtMs;
}

export interface Summary {
  pushReturned: number;
  pushTotal: number;
  holdoutReturned: number;
  holdoutTotal: number;
  pushRate: number;
  holdoutRate: number;
  /** pushRate - holdoutRate, in percentage points. */
  liftPoints: number;
  verdict: "not enough data yet" | "push helps" | "no clear benefit";
}

/** Minimum people per group before the comparison means anything. */
export const MIN_GROUP_SIZE = 30;
/** Smallest difference in return rate (percentage points) counted as a real benefit. */
export const MIN_LIFT_POINTS = 2;

/** Compares how often pushed vs. held-out people came back. */
export function summarize(
  pushReturned: number,
  pushTotal: number,
  holdoutReturned: number,
  holdoutTotal: number
): Summary {
  const rate = (r: number, t: number) => (t === 0 ? 0 : r / t);
  const pushRate = rate(pushReturned, pushTotal);
  const holdoutRate = rate(holdoutReturned, holdoutTotal);
  const liftPoints = Math.round((pushRate - holdoutRate) * 1000) / 10;
  let verdict: Summary["verdict"];
  if (pushTotal < MIN_GROUP_SIZE || holdoutTotal < MIN_GROUP_SIZE) verdict = "not enough data yet";
  else verdict = liftPoints >= MIN_LIFT_POINTS ? "push helps" : "no clear benefit";
  return { pushReturned, pushTotal, holdoutReturned, holdoutTotal, pushRate, holdoutRate, liftPoints, verdict };
}
