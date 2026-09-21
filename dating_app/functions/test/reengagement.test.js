// Run with: npm test   (uses Node's built-in test runner — no extra packages)
const test = require("node:test");
const assert = require("node:assert/strict");
const L = require("../lib/reengagement_logic");

const NOW = Date.UTC(2026, 8, 21, 14, 0, 0);
const ok = { profileComplete: true, accountActive: true, hasToken: true, promotionalOptIn: true };

test("holdout group is stable per user and about 10% of users", () => {
  assert.equal(L.reengagementGroup("abc123"), L.reengagementGroup("abc123"));
  let holdout = 0;
  const n = 20000;
  for (let i = 0; i < n; i++) if (L.reengagementGroup("user-" + i) === "holdout") holdout++;
  const share = holdout / n;
  assert.ok(share > 0.08 && share < 0.12, `holdout share was ${share}`);
});

test("an eligible person may be pushed", () => {
  assert.equal(L.skipReason(ok, NOW), null);
});

test("each disqualifier is reported", () => {
  assert.equal(L.skipReason({ ...ok, profileComplete: false }, NOW), "incomplete");
  assert.equal(L.skipReason({ ...ok, accountActive: false }, NOW), "inactive-account");
  assert.equal(L.skipReason({ ...ok, promotionalOptIn: false }, NOW), "opted-out");
  assert.equal(L.skipReason({ ...ok, hasToken: false }, NOW), "no-token");
});

test("never pushes the same person more than once every 3 days", () => {
  const day = L.DAY_MS;
  assert.equal(L.skipReason({ ...ok, lastSentAtMs: NOW - 1 * day }, NOW), "too-soon");
  assert.equal(L.skipReason({ ...ok, lastSentAtMs: NOW - 2.9 * day }, NOW), "too-soon");
  assert.equal(L.skipReason({ ...ok, lastSentAtMs: NOW - 3 * day }, NOW), null);
  assert.equal(L.skipReason({ ...ok, lastSentAtMs: NOW - 10 * day }, NOW), null);
});

test("an opted-out person is never pushed, even if everything else is fine", () => {
  assert.equal(L.skipReason({ ...ok, promotionalOptIn: false, lastSentAtMs: undefined }, NOW), "opted-out");
});

test("message: pending likes win, singular and plural", () => {
  const one = L.pickMessage({ pendingLikes: 1, newPeopleThisWeek: 50 });
  assert.equal(one.kind, "likes");
  assert.match(one.body, /^1 person liked your profile/);
  const many = L.pickMessage({ pendingLikes: 4, newPeopleThisWeek: 0 });
  assert.match(many.body, /^4 people liked your profile/);
});

test("message: new-people only when there really are enough of them", () => {
  const m = L.pickMessage({ pendingLikes: 0, newPeopleThisWeek: 12 });
  assert.equal(m.kind, "new_people");
  assert.match(m.body, /12 new people/);
  assert.equal(L.pickMessage({ pendingLikes: 0, newPeopleThisWeek: 4 }).kind, "generic");
});

test("message never claims something untrue when there is nothing to report", () => {
  const m = L.pickMessage({ pendingLikes: 0, newPeopleThisWeek: 0 });
  assert.equal(m.kind, "generic");
  assert.doesNotMatch(m.body, /liked|new people/);
});

test("returnedAfter: only later activity counts as coming back", () => {
  assert.equal(L.returnedAfter(NOW + 1000, NOW), true);
  assert.equal(L.returnedAfter(NOW, NOW), false);
  assert.equal(L.returnedAfter(NOW - 5000, NOW), false);
  assert.equal(L.returnedAfter(undefined, NOW), false);
});

test("summary: not enough data until both groups reach 30", () => {
  assert.equal(L.summarize(10, 29, 3, 40).verdict, "not enough data yet");
  assert.equal(L.summarize(10, 40, 3, 29).verdict, "not enough data yet");
});

test("summary: says the push helps only for a real lift", () => {
  const helps = L.summarize(40, 100, 25, 100); // 40% vs 25%
  assert.equal(helps.verdict, "push helps");
  assert.equal(helps.liftPoints, 15);
  assert.equal(L.summarize(26, 100, 25, 100).verdict, "no clear benefit"); // +1 point
  assert.equal(L.summarize(20, 100, 30, 100).verdict, "no clear benefit"); // worse
});

test("summary handles empty groups without dividing by zero", () => {
  const s = L.summarize(0, 0, 0, 0);
  assert.equal(s.pushRate, 0);
  assert.equal(s.verdict, "not enough data yet");
});
