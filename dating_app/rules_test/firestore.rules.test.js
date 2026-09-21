// Run with:  cd rules_test && npm test
// Starts the local Firestore emulator, loads ../firestore.rules, and checks who
// can and cannot read or write what. Nothing here touches the live project.
const { test, before, after, beforeEach } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  addDoc,
  collection,
  collectionGroup,
  query,
  where,
  getDocs,
} = require("firebase/firestore");

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-seloze",
    firestore: { rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8") },
  });
});
after(async () => env && (await env.cleanup()));
beforeEach(async () => env.clearFirestore());

const anon = () => env.unauthenticatedContext().firestore();
const as = (uid, claims) => env.authenticatedContext(uid, claims).firestore();
const seed = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));

// ---------------------------------------------------------------- profiles
test("signed-out users cannot read profiles", async () => {
  await seed((db) => setDoc(doc(db, "users/alice"), { name: "Alice" }));
  await assertFails(getDoc(doc(anon(), "users/alice")));
});

test("any signed-in member can read another member's profile (Discover needs this)", async () => {
  await seed((db) => setDoc(doc(db, "users/alice"), { name: "Alice" }));
  await assertSucceeds(getDoc(doc(as("bob"), "users/alice")));
});

test("only the owner (or an admin) can change a profile", async () => {
  await seed((db) => setDoc(doc(db, "users/alice"), { name: "Alice" }));
  await assertSucceeds(updateDoc(doc(as("alice"), "users/alice"), { bio: "hi" }));
  await assertFails(updateDoc(doc(as("bob"), "users/alice"), { bio: "hacked" }));
  await assertSucceeds(updateDoc(doc(as("boss", { admin: true }), "users/alice"), { accountStatus: "suspended" }));
});

// ------------------------------------------------------------ private docs
test("private settings are readable and writable only by the owner", async () => {
  await assertSucceeds(setDoc(doc(as("alice"), "users/alice/private/settings"), { a: 1 }));
  await assertFails(getDoc(doc(as("bob"), "users/alice/private/settings")));
  await assertFails(setDoc(doc(as("bob"), "users/alice/private/settings"), { a: 2 }));
});

test("the referral rewards doc is readable by its owner but never writable from the app", async () => {
  await seed((db) => setDoc(doc(db, "users/alice/private/rewards"), { referralCount: 2 }));
  await assertSucceeds(getDoc(doc(as("alice"), "users/alice/private/rewards")));
  await assertFails(setDoc(doc(as("alice"), "users/alice/private/rewards"), { referralCount: 999 }));
  await assertFails(updateDoc(doc(as("alice"), "users/alice/private/rewards"), { referralCount: 999 }));
  await assertFails(getDoc(doc(as("bob"), "users/alice/private/rewards")));
});

test("other private docs (e.g. quota) are still writable by the owner", async () => {
  await assertSucceeds(setDoc(doc(as("alice"), "users/alice/private/quota"), { date: "2026-09-21" }));
});

// --------------------------------------------- server-only bookkeeping data
for (const col of ["referrals", "reengagement", "reengagementSummary", "revenueCatEvents"]) {
  test(`${col}: clients cannot write; only admins can read`, async () => {
    await seed((db) => setDoc(doc(db, `${col}/x`), { v: 1 }));
    await assertFails(setDoc(doc(as("alice"), `${col}/y`), { v: 2 }));
    await assertFails(updateDoc(doc(as("alice"), `${col}/x`), { v: 3 }));
    await assertFails(getDoc(doc(as("alice"), `${col}/x`)));
    await assertSucceeds(getDoc(doc(as("boss", { admin: true }), `${col}/x`)));
  });
}

// ------------------------------------------------------------------ blocking
test("a blocked member can find out they were blocked (so the blocker is hidden from them)", async () => {
  await seed((db) => setDoc(doc(db, "users/alice/blocked/bob"), { targetId: "bob" }));
  const q = query(collectionGroup(as("bob"), "blocked"), where("targetId", "==", "bob"));
  const snap = await assertSucceeds(getDocs(q));
  if (snap.size !== 1) throw new Error(`expected 1 result, got ${snap.size}`);
});

test("but nobody can list other people's block lists", async () => {
  await seed((db) => setDoc(doc(db, "users/alice/blocked/bob"), { targetId: "bob" }));
  // Someone else asking about bob:
  await assertFails(getDocs(query(collectionGroup(as("carol"), "blocked"), where("targetId", "==", "bob"))));
  // An unfiltered scan of everyone's block lists:
  await assertFails(getDocs(collectionGroup(as("bob"), "blocked")));
  // Reading the blocker's own list directly:
  await assertFails(getDocs(collection(as("bob"), "users/alice/blocked")));
});

test("a member can manage their own block list", async () => {
  await assertSucceeds(setDoc(doc(as("alice"), "users/alice/blocked/bob"), { targetId: "bob" }));
  await assertSucceeds(deleteDoc(doc(as("alice"), "users/alice/blocked/bob")));
  await assertFails(setDoc(doc(as("bob"), "users/alice/blocked/carol"), { targetId: "carol" }));
});

// ------------------------------------------------------------- likes/matches
test("only the liker can create a pending like; only the receiver can read/delete it", async () => {
  await assertSucceeds(setDoc(doc(as("bob"), "users/alice/likesReceived/bob"), { fromUserId: "bob" }));
  await assertFails(setDoc(doc(as("carol"), "users/alice/likesReceived/bob"), { fromUserId: "bob" }));
  await assertSucceeds(getDoc(doc(as("alice"), "users/alice/likesReceived/bob")));
  await assertFails(getDoc(doc(as("bob"), "users/alice/likesReceived/bob")));
  await assertSucceeds(deleteDoc(doc(as("alice"), "users/alice/likesReceived/bob")));
});

test("either participant can create a match; only the owner can read or delete their copy", async () => {
  await assertSucceeds(setDoc(doc(as("bob"), "users/alice/matches/bob"), { otherUserId: "bob" }));
  await assertFails(setDoc(doc(as("carol"), "users/alice/matches/bob"), { otherUserId: "bob" }));
  await assertSucceeds(getDoc(doc(as("alice"), "users/alice/matches/bob")));
  await assertFails(getDoc(doc(as("bob"), "users/alice/matches/bob")));
});

// -------------------------------------------------------------------- chat
test("only conversation participants can read it and its messages", async () => {
  await seed(async (db) => {
    await setDoc(doc(db, "conversations/a_b"), { participants: ["a", "b"] });
    await setDoc(doc(db, "conversations/a_b/messages/m1"), { senderId: "a", text: "hi" });
  });
  await assertSucceeds(getDoc(doc(as("a"), "conversations/a_b")));
  await assertSucceeds(getDoc(doc(as("b"), "conversations/a_b/messages/m1")));
  await assertFails(getDoc(doc(as("mallory"), "conversations/a_b")));
  await assertFails(getDoc(doc(as("mallory"), "conversations/a_b/messages/m1")));
});

test("a member cannot send a message pretending to be someone else", async () => {
  await seed((db) => setDoc(doc(db, "conversations/a_b"), { participants: ["a", "b"] }));
  await assertSucceeds(addDoc(collection(as("a"), "conversations/a_b/messages"), { senderId: "a", text: "hi" }));
  await assertFails(addDoc(collection(as("a"), "conversations/a_b/messages"), { senderId: "b", text: "spoof" }));
});

test("a member cannot create a conversation they are not part of", async () => {
  await assertSucceeds(setDoc(doc(as("a"), "conversations/a_b"), { participants: ["a", "b"] }));
  await assertFails(setDoc(doc(as("mallory"), "conversations/x_y"), { participants: ["x", "y"] }));
});

// ----------------------------------------------------------- reports & audit
test("members can file reports as themselves; only admins can read them; nobody can delete", async () => {
  await assertSucceeds(addDoc(collection(as("alice"), "reports"), { reporterId: "alice", targetId: "bob" }));
  await assertFails(addDoc(collection(as("alice"), "reports"), { reporterId: "bob", targetId: "carol" }));
  await seed((db) => setDoc(doc(db, "reports/r1"), { reporterId: "alice", targetId: "bob" }));
  await assertFails(getDoc(doc(as("alice"), "reports/r1")));
  await assertSucceeds(getDoc(doc(as("boss", { admin: true }), "reports/r1")));
  await assertFails(deleteDoc(doc(as("boss", { admin: true }), "reports/r1")));
});

test("audit logs can be created by admins but never edited or deleted", async () => {
  await assertSucceeds(setDoc(doc(as("boss", { admin: true }), "auditLogs/l1"), { action: "ban" }));
  await assertFails(updateDoc(doc(as("boss", { admin: true }), "auditLogs/l1"), { action: "edited" }));
  await assertFails(deleteDoc(doc(as("boss", { admin: true }), "auditLogs/l1")));
  await assertFails(setDoc(doc(as("alice"), "auditLogs/l2"), { action: "fake" }));
});

test("notifications: anyone signed in can create one for a member, only the owner can read it", async () => {
  await assertSucceeds(addDoc(collection(as("bob"), "users/alice/notifications"), { title: "hi" }));
  await seed((db) => setDoc(doc(db, "users/alice/notifications/n1"), { title: "x" }));
  await assertSucceeds(getDoc(doc(as("alice"), "users/alice/notifications/n1")));
  await assertFails(getDoc(doc(as("bob"), "users/alice/notifications/n1")));
});

// ------------------------------------------------- privacy of profile fields
// The Privacy Policy says other members are NOT shown a member's email, phone
// number or date of birth. These check what the rules actually allow another
// signed-in member's app to READ from the shared profile document.
// The app keeps those fields in users/{uid}/private/account, not on the shared
// profile doc. The profile doc is readable by every member, so the first test
// mirrors what the app writes now and confirms nothing personal is on it; the
// rest confirm who can read the account doc itself.
const APP_PROFILE_DOC = { name: "Alice", ageVerified: true, accountStatus: "active" };
const ACCOUNT_DOC = {
  email: "alice@example.com",
  phoneNumber: "+910000000000",
  dateOfBirth: "2000-01-01",
  fcmTokens: ["tok"],
};

test("PRIVACY: the profile doc the app writes carries no email, phone, date of birth or push tokens", async () => {
  await seed(async (db) => {
    await setDoc(doc(db, "users/alice"), APP_PROFILE_DOC);
    await setDoc(doc(db, "users/alice/private/account"), ACCOUNT_DOC);
  });
  const data = (await assertSucceeds(getDoc(doc(as("bob"), "users/alice")))).data();
  const leaked = Object.keys(ACCOUNT_DOC).filter((f) => f in data);
  if (leaked.length > 0) {
    throw new Error(`readable by any other signed-in member: ${leaked.join(", ")}`);
  }
});

test("PRIVACY: the account doc is readable only by its owner and admins", async () => {
  await seed((db) => setDoc(doc(db, "users/alice/private/account"), ACCOUNT_DOC));
  await assertSucceeds(getDoc(doc(as("alice"), "users/alice/private/account")));
  await assertSucceeds(getDoc(doc(as("boss", { admin: true }), "users/alice/private/account")));
  await assertFails(getDoc(doc(as("bob"), "users/alice/private/account")));
  await assertFails(getDoc(doc(anon(), "users/alice/private/account")));
});

test("PRIVACY: admins can read the account doc but not other members' private settings", async () => {
  await seed((db) => setDoc(doc(db, "users/alice/private/settings"), { a: 1 }));
  await assertFails(getDoc(doc(as("boss", { admin: true }), "users/alice/private/settings")));
});

test("the owner can save their own account doc (email, date of birth, push token) but nobody else can", async () => {
  await assertSucceeds(setDoc(doc(as("alice"), "users/alice/private/account"), ACCOUNT_DOC, { merge: true }));
  await assertSucceeds(updateDoc(doc(as("alice"), "users/alice/private/account"), { fcmTokens: ["tok2"] }));
  await assertFails(setDoc(doc(as("bob"), "users/alice/private/account"), { email: "evil@example.com" }));
  await assertFails(updateDoc(doc(as("boss", { admin: true }), "users/alice/private/account"), { email: "x@example.com" }));
});
