/**
 * Emulator-backed tests for the repo's Firestore and Storage rules.
 *
 * Why this exists: `firebase deploy --only firestore:rules --dry-run` is the
 * only real rules compiler we can run locally, and it needs live credentials,
 * which CI does not have. Loading the rules into the emulator compiles them,
 * so this file is both the "do the rules parse" gate and a behavioural test of
 * the paths that matter (owner isolation, malformed transaction rejection,
 * self-admin escalation, profile-picture ownership and upload limits).
 *
 * `onAuthStateChanged`/plugin quirks do not apply here: these are plain SDK
 * calls against the emulator, so a failure is a real rules failure.
 *
 * Run with `bash tool/rules_tests/run.sh` (boots both emulators).
 */
'use strict';

const fs = require('fs');
const path = require('path');

const {
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, Timestamp } = require('firebase/firestore');
const { ref, uploadBytes, deleteObject, getBytes } = require('firebase/storage');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-wealthsync';
const ROOT = path.join(__dirname, '..', '..');

const OWNER_UID = 'uid-owner';
const OWNER_EMAIL = 'owner@example.com';
const OTHER_UID = 'uid-other';
const OTHER_EMAIL = 'other@example.com';
const ADMIN_UID = 'uid-admin';
const ADMIN_EMAIL = 'admin@example.com';

let checks = 0;
let failures = 0;

async function check(name, fn) {
  checks += 1;
  try {
    await fn();
    console.log(`  ok    ${name}`);
  } catch (error) {
    failures += 1;
    const message = String((error && error.message) || error).split('\n')[0];
    console.error(`  FAIL  ${name}`);
    console.error(`        ${message}`);
  }
}

/** The write/read must succeed. */
async function expectAllowed(promise) {
  await promise;
}

/**
 * The write/read must be rejected by the rules. Only a rules rejection counts:
 * a not-found/network error is rethrown so a broken test cannot masquerade as
 * a passing security assertion.
 */
async function expectDenied(promise) {
  try {
    await promise;
  } catch (error) {
    const code = String((error && error.code) || '');
    if (code.includes('permission-denied') || code.includes('unauthorized')) {
      return;
    }
    throw error;
  }
  throw new Error('expected the request to be denied, but it succeeded');
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(path.join(ROOT, 'storage.rules'), 'utf8'),
    },
  });

  const owner = testEnv.authenticatedContext(OWNER_UID, { email: OWNER_EMAIL });
  const other = testEnv.authenticatedContext(OTHER_UID, { email: OTHER_EMAIL });
  const admin = testEnv.authenticatedContext(ADMIN_UID, { email: ADMIN_EMAIL });
  const anon = testEnv.unauthenticatedContext();

  const ownerDb = owner.firestore();
  const otherDb = other.firestore();
  const adminDb = admin.firestore();
  const anonDb = anon.firestore();

  // Seed state the rules cannot create themselves.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `users/${OWNER_EMAIL}`), {
      email: OWNER_EMAIL,
      uid: OWNER_UID,
    });
    await setDoc(doc(db, `users/${ADMIN_EMAIL}`), {
      email: ADMIN_EMAIL,
      uid: ADMIN_UID,
      isAdmin: true,
    });
    await setDoc(doc(db, `users/${OTHER_EMAIL}`), {
      email: OTHER_EMAIL,
      uid: OTHER_UID,
    });
    // Existing admin-visible transaction, owned by OWNER.
    await setDoc(doc(db, `users/${OWNER_EMAIL}/transactions/tx-1`), {
      amount: -125.5,
      date: Timestamp.now(),
      senderId: OWNER_UID,
      recipientId: '',
    });
  });

  const ownerTx = `users/${OWNER_EMAIL}/transactions`;

  // ---------------------------------------------------------------- Firestore
  console.log('Firestore rules');

  await check('owner can read their own transaction', () =>
    expectAllowed(getDoc(doc(ownerDb, `${ownerTx}/tx-1`))),
  );

  await check('another user cannot read it', () =>
    expectDenied(getDoc(doc(otherDb, `${ownerTx}/tx-1`))),
  );

  await check('an anonymous client cannot read it', () =>
    expectDenied(getDoc(doc(anonDb, `${ownerTx}/tx-1`))),
  );

  await check('admin can read another user\'s transaction', () =>
    expectAllowed(getDoc(doc(adminDb, `${ownerTx}/tx-1`))),
  );

  await check('owner can create a well-formed transaction', () =>
    expectAllowed(
      setDoc(doc(ownerDb, `${ownerTx}/tx-2`), {
        amount: 2500,
        date: Timestamp.now(),
        senderId: '',
        recipientId: OWNER_UID,
      }),
    ),
  );

  await check('a transaction missing amount/date/ids is rejected', () =>
    expectDenied(
      setDoc(doc(ownerDb, `${ownerTx}/tx-bad`), { amount: -1 }),
    ),
  );

  await check('a transaction with a non-numeric amount is rejected', () =>
    expectDenied(
      setDoc(doc(ownerDb, `${ownerTx}/tx-bad-2`), {
        amount: 'lots',
        date: Timestamp.now(),
        senderId: OWNER_UID,
        recipientId: '',
      }),
    ),
  );

  await check('owner cannot write into another user\'s collection', () =>
    expectDenied(
      setDoc(doc(otherDb, `${ownerTx}/tx-3`), {
        amount: -1,
        date: Timestamp.now(),
        senderId: OWNER_UID,
        recipientId: '',
      }),
    ),
  );

  await check('an unknown subcollection is not writable', () =>
    expectDenied(
      setDoc(doc(ownerDb, `users/${OWNER_EMAIL}/not_a_collection/doc-1`), {
        hello: 'world',
      }),
    ),
  );

  await check('self-granting isAdmin on create is rejected', () => {
    const email = 'brand-new@example.com';
    return expectDenied(
      setDoc(doc(anonDb, `users/${email}`), { email, uid: 'uid-new', isAdmin: true }),
    );
  });

  await check('self-granting isAdmin on update is rejected', async () => {
    const email = 'promote-me@example.com';
    const db = testEnv.authenticatedContext('uid-promote', { email }).firestore();
    await expectAllowed(setDoc(doc(db, `users/${email}`), { email, uid: 'uid-promote' }));
    await expectDenied(
      setDoc(doc(db, `users/${email}`), { isAdmin: true }, { merge: true }),
    );
  });

  await check('self-granting pro without a purchase token is rejected', () =>
    expectDenied(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        { subscriptionStatus: 'pro' },
        { merge: true },
      ),
    ),
  );

  // ------------------------------------------------- Trial / referral grants
  // Every case here is a free-Pro path a client could reach without paying.
  // The rules are the only enforcement point (Spark plan: no Cloud Functions),
  // so the bounds are asserted here rather than trusted.
  console.log('Trial and referral rules');

  const DAY = 24 * 60 * 60 * 1000;
  const inDays = (n) => Timestamp.fromMillis(Date.now() + n * DAY);
  const now = () => Timestamp.fromMillis(Date.now());

  let freshSeq = 0;
  function freshUser() {
    freshSeq += 1;
    const uid = `uid-fresh-${freshSeq}`;
    const email = `fresh-${freshSeq}@example.com`;
    const db = testEnv.authenticatedContext(uid, { email }).firestore();
    return { uid, email, db };
  }

  await check('owner can start the 7-day trial', () =>
    expectAllowed(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        { trialEndDate: inDays(7) },
        { merge: true },
      ),
    ),
  );

  await check('a second free trial is rejected', () =>
    expectDenied(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        { trialEndDate: inDays(7) },
        { merge: true },
      ),
    ),
  );

  await check('a 45-day "first trial" is rejected', async () => {
    const u = freshUser();
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), { email: u.email, uid: u.uid }),
    );
    await expectDenied(
      setDoc(
        doc(u.db, `users/${u.email}`),
        { trialEndDate: inDays(45) },
        { merge: true },
      ),
    );
  });

  // The update rule ORs its branches, so each grant branch must verify
  // ownership itself. A missing check here let any signed-in user write any
  // other account's profile, because "the target has no trialEndDate yet" is
  // true for every fresh account.
  await check("the trial branch cannot write another account's profile", async () => {
    const victim = freshUser();
    const attacker = freshUser();
    await expectAllowed(
      setDoc(doc(victim.db, `users/${victim.email}`), {
        email: victim.email,
        uid: victim.uid,
      }),
    );
    await expectDenied(
      setDoc(
        doc(attacker.db, `users/${victim.email}`),
        { trialEndDate: inDays(7) },
        { merge: true },
      ),
    );
    await expectDenied(
      setDoc(
        doc(attacker.db, `users/${victim.email}`),
        { trialEndDate: inDays(7), name: 'pwned' },
        { merge: true },
      ),
    );
  });

  await check('the trial branch cannot smuggle other fields', async () => {
    const u = freshUser();
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), { email: u.email, uid: u.uid }),
    );
    // hasOnly(['trialEndDate']) is what keeps this branch a trial grant rather
    // than a general-purpose profile write.
    await expectDenied(
      setDoc(
        doc(u.db, `users/${u.email}`),
        { trialEndDate: inDays(7), name: 'Renamed' },
        { merge: true },
      ),
    );
  });

  await check('cancelling a trial (moving the end earlier) is allowed', () =>
    expectAllowed(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        {
          subscriptionStatus: 'free',
          isPro: false,
          trialEndDate: inDays(-0.001),
        },
        { merge: true },
      ),
    ),
  );

  await check('a made-up code cannot unlock a referral month', async () => {
    const u = freshUser();
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), { email: u.email, uid: u.uid }),
    );
    // `referredBy` with no code document (and no 30-day grant attempt) is just
    // a field, but it must not unlock a trial.
    await expectDenied(
      setDoc(
        doc(u.db, `users/${u.email}`),
        { referredBy: 'NOPE1234', trialEndDate: inDays(30) },
        { merge: true },
      ),
    );
  });

  // A code the OWNER can hand out, and a referee who applies it.
  await check('a code document can be created without the owner email', () =>
    expectAllowed(
      setDoc(doc(ownerDb, 'referralCodes/OWNER123'), { ownerUid: OWNER_UID }),
    ),
  );

  await check('creating a code owned by someone else is rejected', () =>
    expectDenied(
      setDoc(doc(otherDb, 'referralCodes/STOLEN12'), { ownerUid: OWNER_UID }),
    ),
  );

  await check('a referee can apply a real code', () =>
    expectAllowed(
      setDoc(
        doc(otherDb, `users/${OTHER_EMAIL}`),
        { referredBy: 'OWNER123', trialEndDate: inDays(30) },
        { merge: true },
      ),
    ),
  );

  await check('the same profile cannot apply a second code', () =>
    expectDenied(
      setDoc(
        doc(otherDb, `users/${OTHER_EMAIL}`),
        { referredBy: 'OWNER123', trialEndDate: inDays(45) },
        { merge: true },
      ),
    ),
  );

  await check('applying your own code is rejected', () =>
    expectDenied(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        { referredBy: 'OWNER123', trialEndDate: inDays(30) },
        { merge: true },
      ),
    ),
  );

  await check('a "referral month" longer than 30 days is rejected', async () => {
    const u = freshUser();
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), { email: u.email, uid: u.uid }),
    );
    await expectDenied(
      setDoc(
        doc(u.db, `users/${u.email}`),
        { referredBy: 'OWNER123', trialEndDate: inDays(40) },
        { merge: true },
      ),
    );
  });

  await check('a referee appends their own claim', () =>
    expectAllowed(
      setDoc(
        doc(otherDb, 'referralCodes/OWNER123'),
        { claims: { [OTHER_UID]: now() } },
        { merge: true },
      ),
    ),
  );

  await check('a claim cannot be appended for someone else', async () => {
    const u = freshUser();
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), { email: u.email, uid: u.uid }),
    );
    await expectDenied(
      setDoc(
        doc(u.db, 'referralCodes/OWNER123'),
        { claims: { [OTHER_UID]: now(), [u.uid]: now() } },
        { merge: true },
      ),
    );
  });

  await check('a referrer cannot grant Pro to another user', () =>
    expectDenied(
      setDoc(
        doc(otherDb, `users/${OWNER_EMAIL}`),
        {
          subscriptionStatus: 'pro',
          referralCount: 5,
          trialEndDate: inDays(45),
        },
        { merge: true },
      ),
    ),
  );

  await check('an unclaimed trial extension on your own profile is rejected', () =>
    expectDenied(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        { trialEndDate: inDays(30), referralCredited: { ghost: now() } },
        { merge: true },
      ),
    ),
  );

  await check('the profile records its own code', () =>
    expectAllowed(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        { referralCode: 'OWNER123' },
        { merge: true },
      ),
    ),
  );

  await check('a claim-backed payout is allowed', () =>
    expectAllowed(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        {
          referralCount: 1,
          trialEndDate: inDays(30),
          referralCredited: { [OTHER_UID]: now() },
        },
        { merge: true },
      ),
    ),
  );

  await check('the same claim cannot be paid twice', () =>
    expectDenied(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        {
          referralCount: 2,
          trialEndDate: inDays(40),
          referralCredited: { [OTHER_UID]: now() },
        },
        { merge: true },
      ),
    ),
  );

  await check('the credited marker cannot be cleared', () =>
    expectDenied(
      setDoc(
        doc(ownerDb, `users/${OWNER_EMAIL}`),
        { referralCredited: { [OTHER_UID]: now() } },
        { merge: true },
      ),
    ),
  );

  await check('a payout can record the credit on the code document', () =>
    expectAllowed(
      setDoc(
        doc(ownerDb, 'referralCodes/OWNER123'),
        { credited: { [OTHER_UID]: now() } },
        { merge: true },
      ),
    ),
  );

  await check('the code document\'s credited list cannot shrink', () =>
    expectDenied(
      setDoc(
        doc(ownerDb, 'referralCodes/OWNER123'),
        { credited: {} },
        { merge: true },
      ),
    ),
  );

  await check('a payout cannot outrun the claims it credits', async () => {
    const ref = freshUser();
    const referee = freshUser();
    await expectAllowed(
      setDoc(doc(ref.db, `users/${ref.email}`), { email: ref.email, uid: ref.uid }),
    );
    await expectAllowed(
      setDoc(doc(referee.db, `users/${referee.email}`), {
        email: referee.email,
        uid: referee.uid,
      }),
    );
    await expectAllowed(
      setDoc(doc(ref.db, 'referralCodes/BIGPAY01'), { ownerUid: ref.uid }),
    );
    await expectAllowed(
      setDoc(
        doc(referee.db, 'referralCodes/BIGPAY01'),
        { claims: { [referee.uid]: now() } },
        { merge: true },
      ),
    );
    await expectAllowed(
      setDoc(doc(ref.db, `users/${ref.email}`), { referralCode: 'BIGPAY01' }),
    );
    // One claim, but 40 days requested.
    await expectDenied(
      setDoc(
        doc(ref.db, `users/${ref.email}`),
        {
          referralCount: 1,
          trialEndDate: inDays(40),
          referralCredited: { [referee.uid]: now() },
        },
        { merge: true },
      ),
    );
  });

  await check('the explicit data-erase reset is allowed', async () => {
    const u = freshUser();
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), {
        email: u.email,
        uid: u.uid,
        subscriptionStatus: 'free',
        trialEndDate: inDays(-1),
        referralCode: 'OWNER123',
      }),
    );
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), {
        email: u.email,
        consent_data: false,
        consent_marketing: false,
        dataDeletedAt: now(),
      }),
    );

    // A Pro user erasing: the gated entitlement fields are gone, the purchase
    // token is left in place, and the write must still be allowed — the erase
    // checks what is *absent*, not what the doc used to hold.
    const pro = freshUser();
    await expectAllowed(
      setDoc(doc(pro.db, `users/${pro.email}`), {
        email: pro.email,
        uid: pro.uid,
        subscriptionStatus: 'pro',
        isPro: true,
        purchaseToken: 'real-looking-token',
      }),
    );
    await expectAllowed(
      setDoc(doc(pro.db, `users/${pro.email}`), {
        email: pro.email,
        consent_data: false,
        consent_marketing: false,
        dataDeletedAt: now(),
        purchaseToken: 'real-looking-token',
      }),
    );
  });

  // The erase branch may touch any field, so it must also refuse to put a gated
  // value back — otherwise "erase my data" doubles as "make me an admin".
  await check('the erase reset cannot mint an admin', async () => {
    const u = freshUser();
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), { email: u.email, uid: u.uid }),
    );
    await expectDenied(
      setDoc(
        doc(u.db, `users/${u.email}`),
        { consent_data: false, dataDeletedAt: now(), isAdmin: true },
        { merge: true },
      ),
    );
  });

  await check('the erase reset cannot grant or keep a trial', async () => {
    const u = freshUser();
    await expectAllowed(
      setDoc(doc(u.db, `users/${u.email}`), { email: u.email, uid: u.uid }),
    );
    await expectDenied(
      setDoc(
        doc(u.db, `users/${u.email}`),
        { consent_data: false, dataDeletedAt: now(), trialEndDate: inDays(30) },
        { merge: true },
      ),
    );
    // Nor claim Pro while erasing without a purchase claim. (A *forged* token
    // is a separate, documented residual: `validProClaim` can only prove a
    // token exists — it is the owner-update branch that accepts it, not this
    // one, and a Blaze Cloud Function is the fix.)
    await expectDenied(
      setDoc(
        doc(u.db, `users/${u.email}`),
        {
          consent_data: false,
          dataDeletedAt: now(),
          subscriptionStatus: 'pro',
          isPro: true,
        },
        { merge: true },
      ),
    );
  });

  // ------------------------------------------------------------------ Storage
  console.log('Storage rules');

  const ownerStorage = owner.storage();
  const otherStorage = other.storage();
  const anonStorage = anon.storage();

  const imageBytes = new Uint8Array([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46,
  ]);
  const imageMeta = { contentType: 'image/jpeg' };
  const ownerPicture = ref(ownerStorage, `users/${OWNER_UID}/profile.jpg`);

  await check('owner can upload their profile picture', () =>
    expectAllowed(uploadBytes(ownerPicture, imageBytes, imageMeta)),
  );

  await check('owner can read their own picture', () =>
    expectAllowed(getBytes(ownerPicture)),
  );

  await check('another user cannot read that picture', () =>
    expectDenied(
      getBytes(ref(otherStorage, `users/${OWNER_UID}/profile.jpg`)),
    ),
  );

  await check('another user cannot upload into that folder', () =>
    expectDenied(
      uploadBytes(
        ref(otherStorage, `users/${OWNER_UID}/profile.jpg`),
        imageBytes,
        imageMeta,
      ),
    ),
  );

  await check('a non-image content type is rejected', () =>
    expectDenied(
      uploadBytes(ref(ownerStorage, `users/${OWNER_UID}/profile.jpg`), imageBytes, {
        contentType: 'application/pdf',
      }),
    ),
  );

  await check('an object name other than profile.jpg is rejected', () =>
    expectDenied(
      uploadBytes(
        ref(ownerStorage, `users/${OWNER_UID}/backup.json`),
        imageBytes,
        imageMeta,
      ),
    ),
  );

  await check('an upload over 5 MB is rejected', () =>
    expectDenied(
      uploadBytes(
        ref(ownerStorage, `users/${OWNER_UID}/profile.jpg`),
        new Uint8Array(5 * 1024 * 1024 + 1),
        imageMeta,
      ),
    ),
  );

  await check('anonymous uploads are denied', () =>
    expectDenied(
      uploadBytes(
        ref(anonStorage, `users/${OWNER_UID}/profile.jpg`),
        imageBytes,
        imageMeta,
      ),
    ),
  );

  await check('owner can delete their picture (account deletion path)', () =>
    expectAllowed(deleteObject(ownerPicture)),
  );

  await testEnv.cleanup();

  console.log('');
  console.log(`${checks - failures}/${checks} rules checks passed`);
  if (failures > 0) {
    console.error(`${failures} rules check(s) failed`);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error('Rules test harness failed to start:', error);
  process.exitCode = 1;
});
