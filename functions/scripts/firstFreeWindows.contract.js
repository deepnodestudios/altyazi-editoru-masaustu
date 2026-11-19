// Contract: Windows first-free translation (Plan 3f, owner decision 2026-11-18).
// Run: npm run test:firstfree (builds first).
const assert = require("node:assert/strict");
const {
    FIRST_FREE_MIN_MOBILE_VERSION,
    FIRST_FREE_MIN_WINDOWS_VERSION,
    usesFirstFreeTranslation,
    firstFreeRequiresGoogleAccount,
    firstFreeSkipsAppCheck,
    hasGoogleIdentity,
} = require("../lib/billing/tokenWallet.js");

// Existing behaviour is unchanged.
assert.equal(FIRST_FREE_MIN_MOBILE_VERSION, "1.8.5");
assert.equal(usesFirstFreeTranslation({ platform: "web" }), true);
assert.equal(usesFirstFreeTranslation({ platform: "android", appVersion: "1.8.5" }), true);
assert.equal(usesFirstFreeTranslation({ platform: "android", appVersion: "1.8.4" }), false);
assert.equal(usesFirstFreeTranslation({ platform: "ios", appVersion: "1.9.0" }), true);
assert.equal(usesFirstFreeTranslation({ platform: "macos", appVersion: "9.9.9" }), false);

// Windows: only the new single-codebase build, never desktop 1.8.6.
assert.equal(FIRST_FREE_MIN_WINDOWS_VERSION, "1.9.6");
assert.equal(usesFirstFreeTranslation({ platform: "windows", appVersion: "1.8.6" }), false);
assert.equal(usesFirstFreeTranslation({ platform: "windows", appVersion: "1.9.5" }), false);
assert.equal(usesFirstFreeTranslation({ platform: "windows", appVersion: "1.9.6" }), true);
assert.equal(usesFirstFreeTranslation({ platform: "windows", appVersion: "1.10.0" }), true);
assert.equal(usesFirstFreeTranslation({ platform: "windows" }), false);

// Google account required on Windows only.
assert.equal(firstFreeRequiresGoogleAccount("windows"), true);
assert.equal(firstFreeRequiresGoogleAccount(" Windows "), true);
assert.equal(firstFreeRequiresGoogleAccount("android"), false);
assert.equal(firstFreeRequiresGoogleAccount("web"), false);

// No App Check on web and Windows; mobile still needs it.
assert.equal(firstFreeSkipsAppCheck("web"), true);
assert.equal(firstFreeSkipsAppCheck("windows"), true);
assert.equal(firstFreeSkipsAppCheck("android"), false);

// Google identity comes from the ID token (also after linking an anonymous user).
assert.equal(
    hasGoogleIdentity({
        firebase: { sign_in_provider: "anonymous", identities: { "google.com": ["123"] } },
    }),
    true,
);
assert.equal(hasGoogleIdentity({ firebase: { sign_in_provider: "anonymous", identities: {} } }), false);
assert.equal(hasGoogleIdentity({ firebase: { identities: { "google.com": [] } } }), false);
assert.equal(hasGoogleIdentity(undefined), false);
assert.equal(hasGoogleIdentity(null), false);

console.log("firstFreeWindows contract OK");
