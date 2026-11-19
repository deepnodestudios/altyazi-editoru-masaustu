// Contract: web and desktop spend paid tokens only (owner decision, Nov
// 2026); their one gift is the free first translation. Grant tokens (mobile
// ad/pack bonuses, the retired web Google-login grant) are never spent there.
// Run for the default codebase and, with a path argument, for the web mirror.
const assert = require("node:assert/strict");
const path = require("node:path");

const modulePath = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(__dirname, "../lib/billing/tokenWallet.js");
const wallet = require(modulePath);

const state = (paid, grant) => ({
  tokenBalance: paid + grant,
  tokenGrantBalance: grant,
  legacyFlatRateRemaining: 0,
  snapshotPending: false,
  convertedBonusTokens: 0,
});

const plan = (platform, paid, grant, appVersion = "1.9.6") => wallet.planTokenWalletCharge({
  state: state(paid, grant),
  bonus: null,
  estimatedTokens: 100000,
  charCount: 0,
  platform,
  appVersion,
  preferFreeCreditsFirst: true,
  // An account that claimed the retired login gift still carries this.
  googleLoginTokenGrantBalance: grant,
});

for (const platform of ["web", "windows"]) {
  // Paid tokens cover it: never touches the grant, even with "bonus first".
  let p = plan(platform, 500_000, 300_000);
  assert.equal(p.mode, "tokens", platform);
  assert.equal(p.fromPaidTokens, 100000, platform);
  assert.equal(p.fromGrantTokens, 0, platform);

  // Only grant tokens: the web and desktop cannot spend them.
  assert.throws(() => plan(platform, 0, 300_000), platform);
}

// Mobile still spends its bonus first when asked.
const m = plan("android", 500_000, 300_000);
assert.equal(m.fromGrantTokens, 100000);

if (typeof wallet.spendableTokenBalance === "function") {
  const s = (platform) => wallet.spendableTokenBalance({
    state: state(200_000, 300_000),
    platform,
    appVersion: "1.9.6",
    googleLoginTokenGrantBalance: 100_000,
  });
  assert.equal(s("web"), 200_000);
  assert.equal(s("windows"), 200_000);
  assert.equal(s("android"), 500_000);
}

console.log("web paid-only contract OK");
