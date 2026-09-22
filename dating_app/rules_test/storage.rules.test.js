// Run with:  cd rules_test && npm test  (starts firestore AND storage emulators)
// Loads ../storage.rules and checks who can read/write what in Cloud Storage.
// This file's rules had NO test coverage before — worse, ../firebase.json had
// no "storage" block at all, so `firebase deploy --only storage` had nothing
// to deploy: these rules may never have reached production. Both are fixed
// alongside adding this file.
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes, deleteObject } = require("firebase/storage");

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-seloze",
    storage: { rules: fs.readFileSync(path.join(__dirname, "..", "storage.rules"), "utf8") },
  });
});
after(async () => env && (await env.cleanup()));
beforeEach(async () => env.clearStorage());

const anon = () => env.unauthenticatedContext().storage();
const as = (uid) => env.authenticatedContext(uid).storage();
const jpeg = new Uint8Array([1, 2, 3]);
const audio = new Uint8Array([4, 5, 6]);

// ------------------------------------------------------------ profile photos
test("the owner can delete their own profile photo", async () => {
  await assertSucceeds(
    uploadBytes(ref(as("alice"), "profile_photos/alice/1.jpg"), jpeg, { contentType: "image/jpeg" })
  );
  await assertSucceeds(deleteObject(ref(as("alice"), "profile_photos/alice/1.jpg")));
});

test("signed-out users cannot read or write profile photos", async () => {
  await assertFails(getBytes(ref(anon(), "profile_photos/alice/1.jpg")));
  await assertFails(
    uploadBytes(ref(anon(), "profile_photos/alice/1.jpg"), jpeg, { contentType: "image/jpeg" })
  );
});

test("any signed-in user can read a profile photo (Discover/chat need this)", async () => {
  await assertSucceeds(
    uploadBytes(ref(as("alice"), "profile_photos/alice/1.jpg"), jpeg, { contentType: "image/jpeg" })
  );
  await assertSucceeds(getBytes(ref(as("bob"), "profile_photos/alice/1.jpg")));
});

test("only the owner can write into their own profile_photos folder", async () => {
  await assertFails(
    uploadBytes(ref(as("bob"), "profile_photos/alice/1.jpg"), jpeg, { contentType: "image/jpeg" })
  );
});

test("profile photo uploads are rejected over 10MB or with a non-image content type", async () => {
  const tooBig = new Uint8Array(10 * 1024 * 1024 + 1);
  await assertFails(uploadBytes(ref(as("alice"), "profile_photos/alice/big.jpg"), tooBig, { contentType: "image/jpeg" }));
  await assertFails(
    uploadBytes(ref(as("alice"), "profile_photos/alice/x.jpg"), jpeg, { contentType: "application/octet-stream" })
  );
});

// --------------------------------------------------------------- chat audio
test("only the two participants (by conversationId) can read a voice note", async () => {
  await assertSucceeds(
    uploadBytes(ref(as("alice"), "chat_audio/alice_bob/note.m4a"), audio, { contentType: "audio/mp4" })
  );
  await assertSucceeds(getBytes(ref(as("alice"), "chat_audio/alice_bob/note.m4a")));
  await assertSucceeds(getBytes(ref(as("bob"), "chat_audio/alice_bob/note.m4a")));
  await assertFails(getBytes(ref(as("mallory"), "chat_audio/alice_bob/note.m4a")));
  await assertFails(getBytes(ref(anon(), "chat_audio/alice_bob/note.m4a")));
});

test("a non-participant cannot upload into someone else's conversation", async () => {
  await assertFails(
    uploadBytes(ref(as("mallory"), "chat_audio/alice_bob/spam.m4a"), audio, { contentType: "audio/mp4" })
  );
});

test("voice note uploads are rejected over 5MB or with a non-audio content type", async () => {
  const tooBig = new Uint8Array(5 * 1024 * 1024 + 1);
  await assertFails(
    uploadBytes(ref(as("alice"), "chat_audio/alice_bob/big.m4a"), tooBig, { contentType: "audio/mp4" })
  );
  await assertFails(
    uploadBytes(ref(as("alice"), "chat_audio/alice_bob/x.m4a"), audio, { contentType: "application/octet-stream" })
  );
});

test("a deleted account's voice notes are actually removable (owner can delete their own upload)", async () => {
  await assertSucceeds(
    uploadBytes(ref(as("alice"), "chat_audio/alice_bob/note.m4a"), audio, { contentType: "audio/mp4" })
  );
  // Storage rules don't define a separate `delete` — `write` covers create/
  // update/delete unless split out, so this doubles as regression coverage
  // for that: cleanupUserOnDelete's bucket.deleteFiles() uses the Admin SDK
  // (bypasses rules entirely) but a client-side delete path, if one is ever
  // added, needs this to actually be reachable by a participant.
  await assertSucceeds(deleteObject(ref(as("alice"), "chat_audio/alice_bob/note.m4a")));
});

test("sanity: a completely unmatched path is denied to everyone", async () => {
  await assertFails(getBytes(ref(as("alice"), "something_else/random.txt")));
  assert.ok(true);
});
