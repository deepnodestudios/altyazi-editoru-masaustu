import * as admin from 'firebase-admin';

import type { TokenWalletState } from './tokenWallet';

export const GRANT_TTL_MS = 30 * 24 * 60 * 60 * 1000;
export const TOKEN_GRANT_LOTS_COLLECTION = 'token_grant_lots';
export const BONUS_TOKEN_EXPIRY_REASON = 'bonus_token_expiry';
export const GOOGLE_LOGIN_GRANT_SOURCE = 'google_login_bonus';

export type GrantLotStatus = 'active' | 'consumed' | 'expired' | 'revoked';

export type GrantLotSource =
  | 'ad_reward'
  | 'starter_bonus'
  | 'google_login_bonus'
  | 'referral'
  | 'purchase_bonus'
  | 'subscription_bonus'
  | 'legacy_conversion'
  | 'migration'
  | string;

export interface GrantLotDoc {
  id: string;
  amountGranted: number;
  remaining: number;
  grantedAt: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp;
  status: GrantLotStatus;
  source: GrantLotSource;
  originId: string;
  productId?: string | null;
  deviceId?: string | null;
}

export function grantExpiresAt(grantedAt: Date): Date {
  return new Date(grantedAt.getTime() + GRANT_TTL_MS);
}

export function grantLotsCollection(
  userRef: FirebaseFirestore.DocumentReference,
): FirebaseFirestore.CollectionReference {
  return userRef.collection(TOKEN_GRANT_LOTS_COLLECTION);
}

export function lotDocIdFromOrigin(originId: string): string {
  const safe = String(originId || '')
    .trim()
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .slice(0, 700);
  if (!safe) {
    return `lot_${Date.now()}`;
  }
  return safe.startsWith('lot_') ? safe : `lot_${safe}`;
}

function clampNonNegativeInt(value: unknown): number {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return 0;
  return Math.floor(n);
}

function toTimestamp(value: unknown, fallback: admin.firestore.Timestamp): admin.firestore.Timestamp {
  if (value instanceof admin.firestore.Timestamp) return value;
  if (value instanceof Date && Number.isFinite(value.getTime())) {
    return admin.firestore.Timestamp.fromDate(value);
  }
  const millis = Number(value);
  if (Number.isFinite(millis) && millis > 0) {
    return admin.firestore.Timestamp.fromMillis(millis);
  }
  return fallback;
}

export function parseGrantLotDoc(
  id: string,
  data: FirebaseFirestore.DocumentData,
): GrantLotDoc {
  const nowTs = admin.firestore.Timestamp.now();
  const grantedAt = toTimestamp(data.grantedAt, nowTs);
  const defaultExpiry = admin.firestore.Timestamp.fromDate(
    grantExpiresAt(grantedAt.toDate()),
  );
  const expiresAt = toTimestamp(data.expiresAt, defaultExpiry);
  return {
    id,
    amountGranted: clampNonNegativeInt(data.amountGranted),
    remaining: clampNonNegativeInt(data.remaining),
    grantedAt,
    expiresAt,
    status: (String(data.status ?? 'active') as GrantLotStatus),
    source: String(data.source ?? 'unknown'),
    originId: String(data.originId ?? id),
    productId: data.productId == null ? null : String(data.productId),
    deviceId: data.deviceId == null ? null : String(data.deviceId),
  };
}

export async function loadActiveGrantLots(
  tx: FirebaseFirestore.Transaction,
  userRef: FirebaseFirestore.DocumentReference,
): Promise<GrantLotDoc[]> {
  const snap = await tx.get(
    grantLotsCollection(userRef)
      .where('status', '==', 'active')
      .orderBy('expiresAt', 'asc'),
  );
  return snap.docs.map((doc) => parseGrantLotDoc(doc.id, doc.data() ?? {}));
}

/**
 * Includes consumed/expired rows so callers can distinguish a tracked,
 * exhausted Google-login grant from an older pre-lot account.
 */
export async function loadGoogleLoginGrantLots(
  userRef: FirebaseFirestore.DocumentReference,
  tx?: FirebaseFirestore.Transaction,
): Promise<GrantLotDoc[]> {
  const query = grantLotsCollection(userRef)
    .where('source', '==', GOOGLE_LOGIN_GRANT_SOURCE);
  const snap = tx == null ? await query.get() : await tx.get(query);
  return snap.docs.map((doc) => parseGrantLotDoc(doc.id, doc.data() ?? {}));
}

export function sumActiveLotRemaining(lots: GrantLotDoc[]): number {
  return lots.reduce((sum, lot) => {
    if (lot.status !== 'active') return sum;
    return sum + Math.max(0, lot.remaining);
  }, 0);
}

const SUBSCRIPTION_GRANT_SOURCE = 'subscription_bonus';
const LEGACY_UNATTRIBUTED_GRANT_SOURCES = new Set([
  'migration',
  'legacy_conversion',
]);

function normalizedLotSource(lot: GrantLotDoc): string {
  return String(lot.source).trim().toLowerCase();
}

export function sumActiveLotRemainingBySources(
  lots: GrantLotDoc[],
  sources: string[],
): number {
  const accepted = new Set(sources.map((source) => source.trim().toLowerCase()));
  return lots.reduce((sum, lot) => {
    if (lot.status !== 'active' || lot.remaining <= 0) return sum;
    return accepted.has(normalizedLotSource(lot))
      ? sum + lot.remaining
      : sum;
  }, 0);
}

/**
 * Rebuild the subscription-grant sub-balance from source-tagged lots.
 * Pre-lot wallets may only have migration/legacy_conversion inventory; retain
 * at most their previously recorded subscription slice until it is consumed.
 */
export function reconcileSubscriptionGrantRemainingFromLots(
  state: TokenWalletState,
  lots: GrantLotDoc[],
  opts?: { legacyUnattributedLimit?: number },
): TokenWalletState {
  const tracked = sumActiveLotRemainingBySources(
    lots,
    [SUBSCRIPTION_GRANT_SOURCE],
  );
  const legacyInventory = sumActiveLotRemainingBySources(
    lots,
    [...LEGACY_UNATTRIBUTED_GRANT_SOURCES],
  );
  const previouslyUnattributed = opts?.legacyUnattributedLimit == null
    ? Math.max(
      0,
      clampNonNegativeInt(state.subscriptionTokenGrantRemaining) - tracked,
    )
    : clampNonNegativeInt(opts.legacyUnattributedLimit);
  const reconciled = Math.min(
    clampNonNegativeInt(state.tokenGrantBalance),
    tracked + Math.min(previouslyUnattributed, legacyInventory),
  );
  if (reconciled === state.subscriptionTokenGrantRemaining) return state;
  return {
    ...state,
    subscriptionTokenGrantRemaining: reconciled,
  };
}

function writeLotUpdate(
  tx: FirebaseFirestore.Transaction,
  userRef: FirebaseFirestore.DocumentReference,
  lot: GrantLotDoc,
): void {
  const ref = grantLotsCollection(userRef).doc(lot.id);
  tx.set(ref, {
    amountGranted: lot.amountGranted,
    remaining: lot.remaining,
    grantedAt: lot.grantedAt,
    expiresAt: lot.expiresAt,
    status: lot.status,
    source: lot.source,
    originId: lot.originId,
    productId: lot.productId ?? null,
    deviceId: lot.deviceId ?? null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

/**
 * Create a grant lot. Does not read inside the transaction (Firestore: no reads after writes).
 * Callers should use unique originIds or rely on outer idempotency (purchase processed, etc.).
 * Caller must have already increased tokenGrantBalance on the wallet state.
 */
export function recordGrantLotInTx(
  tx: FirebaseFirestore.Transaction,
  userRef: FirebaseFirestore.DocumentReference,
  args: {
    amount: number;
    source: GrantLotSource;
    originId: string;
    grantedAt?: Date;
    productId?: string | null;
    deviceId?: string | null;
    lotId?: string;
    /** When provided, skip creating a duplicate in-memory / known lot. */
    existingLots?: GrantLotDoc[];
  },
): GrantLotDoc | null {
  const amount = clampNonNegativeInt(args.amount);
  if (amount <= 0) return null;

  const lotId = args.lotId ?? lotDocIdFromOrigin(args.originId);
  if (args.existingLots?.some((lot) => lot.id === lotId && lot.remaining > 0)) {
    return args.existingLots.find((lot) => lot.id === lotId) ?? null;
  }

  const grantedAtDate = args.grantedAt ?? new Date();
  const grantedAt = admin.firestore.Timestamp.fromDate(grantedAtDate);
  const expiresAt = admin.firestore.Timestamp.fromDate(grantExpiresAt(grantedAtDate));
  const lot: GrantLotDoc = {
    id: lotId,
    amountGranted: amount,
    remaining: amount,
    grantedAt,
    expiresAt,
    status: 'active',
    source: args.source,
    originId: args.originId,
    productId: args.productId ?? null,
    deviceId: args.deviceId ?? null,
  };
  tx.set(grantLotsCollection(userRef).doc(lotId), {
    amountGranted: lot.amountGranted,
    remaining: lot.remaining,
    grantedAt: lot.grantedAt,
    expiresAt: lot.expiresAt,
    status: lot.status,
    source: lot.source,
    originId: lot.originId,
    productId: lot.productId,
    deviceId: lot.deviceId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return lot;
}

/**
 * If active lots cover less than tokenGrantBalance, create a migration lot for the gap.
 * Returns updated lots array (in-memory).
 */
export function ensureGrantLotsConsistentInTx(
  tx: FirebaseFirestore.Transaction,
  userRef: FirebaseFirestore.DocumentReference,
  state: Pick<TokenWalletState, 'tokenGrantBalance' | 'convertedBonusTokens'>,
  lots: GrantLotDoc[],
  now: Date = new Date(),
): GrantLotDoc[] {
  // hydrateTokenWallet already includes converted legacy bonuses in the grant
  // aggregate. Those tokens receive their own legacy_conversion lot after this
  // reconciliation, so exclude them from the migration gap to avoid double lots.
  const grantBalance = Math.max(
    0,
    clampNonNegativeInt(state.tokenGrantBalance)
      - clampNonNegativeInt(state.convertedBonusTokens),
  );
  const covered = sumActiveLotRemaining(lots);
  const gap = grantBalance - covered;
  if (gap <= 0) return lots;

  const originId = lots.some((lot) => lot.originId === 'migration_v1' || lot.id === 'lot_migration_v1')
    ? `migration_${now.getTime()}`
    : 'migration_v1';
  const created = recordGrantLotInTx(tx, userRef, {
    amount: gap,
    source: 'migration',
    originId,
    grantedAt: now,
    existingLots: lots,
  });
  if (!created) return lots;
  if (lots.some((lot) => lot.id === created.id)) {
    return lots.map((lot) => (lot.id === created.id ? created : lot));
  }
  return [...lots, created].sort(
    (a, b) => a.expiresAt.toMillis() - b.expiresAt.toMillis(),
  );
}

export function expireDueGrantLotsInTx(
  tx: FirebaseFirestore.Transaction,
  userRef: FirebaseFirestore.DocumentReference,
  state: TokenWalletState,
  lots: GrantLotDoc[],
  now: Date = new Date(),
  opts?: { writeAudit?: boolean },
): {
  next: TokenWalletState;
  lots: GrantLotDoc[];
  expiredAmount: number;
  expiredLotIds: string[];
} {
  const nowMs = now.getTime();
  const reconciledState = reconcileSubscriptionGrantRemainingFromLots(
    state,
    lots,
  );
  const trackedSubscriptionBefore = sumActiveLotRemainingBySources(
    lots,
    [SUBSCRIPTION_GRANT_SOURCE],
  );
  const legacySubscriptionBefore = Math.max(
    0,
    reconciledState.subscriptionTokenGrantRemaining
      - trackedSubscriptionBefore,
  );
  let expiredAmount = 0;
  let expiredTrackedSubscription = 0;
  let expiredLegacyInventory = 0;
  const expiredLotIds: string[] = [];
  const nextLots = lots.map((lot) => {
    if (lot.status !== 'active' || lot.remaining <= 0) return lot;
    if (lot.expiresAt.toMillis() > nowMs) return lot;
    const burned = lot.remaining;
    expiredAmount += burned;
    const source = normalizedLotSource(lot);
    if (source === SUBSCRIPTION_GRANT_SOURCE) {
      expiredTrackedSubscription += burned;
    } else if (LEGACY_UNATTRIBUTED_GRANT_SOURCES.has(source)) {
      expiredLegacyInventory += burned;
    }
    expiredLotIds.push(lot.id);
    const updated: GrantLotDoc = {
      ...lot,
      remaining: 0,
      status: 'expired',
    };
    writeLotUpdate(tx, userRef, updated);
    return updated;
  });

  if (expiredAmount <= 0) {
    return {
      next: reconciledState,
      lots: nextLots,
      expiredAmount: 0,
      expiredLotIds: [],
    };
  }

  const nextGrantBalance = Math.max(
    0,
    reconciledState.tokenGrantBalance - expiredAmount,
  );
  const expiredLegacySubscription = Math.min(
    legacySubscriptionBefore,
    expiredLegacyInventory,
  );
  const next: TokenWalletState = {
    ...reconciledState,
    snapshotPending: false,
    tokenBalance: Math.max(0, reconciledState.tokenBalance - expiredAmount),
    tokenGrantBalance: nextGrantBalance,
    subscriptionTokenGrantRemaining: Math.min(
      nextGrantBalance,
      Math.max(
        0,
        reconciledState.subscriptionTokenGrantRemaining
          - expiredTrackedSubscription
          - expiredLegacySubscription,
      ),
    ),
  };

  if (opts?.writeAudit !== false) {
    const auditRef = userRef.collection('credit_transactions').doc();
    tx.set(auditRef, {
      type: 'spend',
      amount: expiredAmount,
      unit: 'token',
      reason: BONUS_TOKEN_EXPIRY_REASON,
      source: 'bonus_expired',
      creditType: 'token_grant',
      expiredLotIds,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      remainingTokenBalance: next.tokenBalance,
      remainingTokenGrantBalance: next.tokenGrantBalance,
      remainingLegacyFlatRateRemaining: next.legacyFlatRateRemaining,
    });
  }

  return { next, lots: nextLots, expiredAmount, expiredLotIds };
}

export function spendGrantLotsFifoInTx(
  tx: FirebaseFirestore.Transaction,
  userRef: FirebaseFirestore.DocumentReference,
  lots: GrantLotDoc[],
  amount: number,
  now: Date = new Date(),
): {
  lots: GrantLotDoc[];
  spent: number;
  allocations: Array<{ lotId: string; amount: number; source: string }>;
} {
  let remainingToSpend = clampNonNegativeInt(amount);
  const allocations: Array<{ lotId: string; amount: number; source: string }> = [];
  if (remainingToSpend <= 0) {
    return { lots, spent: 0, allocations };
  }

  const nowMs = now.getTime();
  const ordered = [...lots].sort(
    (a, b) => a.expiresAt.toMillis() - b.expiresAt.toMillis(),
  );

  const nextLots = ordered.map((lot) => {
    if (remainingToSpend <= 0) return lot;
    if (lot.status !== 'active' || lot.remaining <= 0) return lot;
    if (lot.expiresAt.toMillis() <= nowMs) return lot; // should already be expired
    const take = Math.min(lot.remaining, remainingToSpend);
    if (take <= 0) return lot;
    remainingToSpend -= take;
    allocations.push({ lotId: lot.id, amount: take, source: String(lot.source) });
    const updated: GrantLotDoc = {
      ...lot,
      remaining: lot.remaining - take,
      status: lot.remaining - take <= 0 ? 'consumed' : 'active',
    };
    writeLotUpdate(tx, userRef, updated);
    return updated;
  });

  const spent = clampNonNegativeInt(amount) - remainingToSpend;
  // Preserve original relative order by id map
  const byId = new Map(nextLots.map((lot) => [lot.id, lot]));
  const merged = lots.map((lot) => byId.get(lot.id) ?? lot);
  for (const lot of nextLots) {
    if (!merged.some((item) => item.id === lot.id)) {
      merged.push(lot);
    }
  }
  return { lots: merged, spent, allocations };
}

/**
 * Reduce grant lots (forfeit / revoke). Prefers matching sources, then any active lots.
 */
export function reduceGrantLotsInTx(
  tx: FirebaseFirestore.Transaction,
  userRef: FirebaseFirestore.DocumentReference,
  lots: GrantLotDoc[],
  amount: number,
  opts: {
    preferSources?: string[];
    preferOriginIds?: string[];
    allowedSources?: string[];
    finalStatus: Extract<GrantLotStatus, 'revoked' | 'expired' | 'consumed'>;
  },
): {
  lots: GrantLotDoc[];
  reduced: number;
} {
  let remaining = clampNonNegativeInt(amount);
  if (remaining <= 0) return { lots, reduced: 0 };

  const preferSources = new Set(
    (opts.preferSources ?? []).map((s) => s.toLowerCase()),
  );
  const preferOrigins = new Set(opts.preferOriginIds ?? []);
  const allowedSources = opts.allowedSources == null
    ? null
    : new Set(opts.allowedSources.map((source) => source.trim().toLowerCase()));

  const rank = (lot: GrantLotDoc): number => {
    let score = 2;
    if (preferOrigins.has(lot.originId) || preferOrigins.has(lot.id)) score = 0;
    else if (preferSources.has(String(lot.source).toLowerCase())) score = 1;
    return score;
  };

  const ordered = [...lots].sort((a, b) => {
    const rankDiff = rank(a) - rank(b);
    if (rankDiff !== 0) return rankDiff;
    return a.expiresAt.toMillis() - b.expiresAt.toMillis();
  });

  const updates = new Map<string, GrantLotDoc>();
  for (const lot of ordered) {
    if (remaining <= 0) break;
    if (lot.status !== 'active' || lot.remaining <= 0) continue;
    if (
      allowedSources != null
      && !allowedSources.has(normalizedLotSource(lot))
    ) {
      continue;
    }
    const take = Math.min(lot.remaining, remaining);
    if (take <= 0) continue;
    remaining -= take;
    const nextRemaining = lot.remaining - take;
    const updated: GrantLotDoc = {
      ...lot,
      remaining: nextRemaining,
      status: nextRemaining <= 0 ? opts.finalStatus : 'active',
    };
    updates.set(lot.id, updated);
    writeLotUpdate(tx, userRef, updated);
  }

  const nextLots = lots.map((lot) => updates.get(lot.id) ?? lot);
  return {
    lots: nextLots,
    reduced: clampNonNegativeInt(amount) - remaining,
  };
}

/**
 * Expire a single lot by id (purge job). Returns burned amount and next wallet fields.
 */
export function expireSingleLotInTx(
  tx: FirebaseFirestore.Transaction,
  userRef: FirebaseFirestore.DocumentReference,
  state: TokenWalletState,
  lot: GrantLotDoc,
): { next: TokenWalletState; burned: number } {
  if (lot.status !== 'active' || lot.remaining <= 0) {
    return { next: state, burned: 0 };
  }
  const burned = lot.remaining;
  const updated: GrantLotDoc = {
    ...lot,
    remaining: 0,
    status: 'expired',
  };
  writeLotUpdate(tx, userRef, updated);
  const nextGrantBalance = Math.max(0, state.tokenGrantBalance - burned);
  const source = normalizedLotSource(lot);
  const subscriptionBurned =
    source === SUBSCRIPTION_GRANT_SOURCE
    || LEGACY_UNATTRIBUTED_GRANT_SOURCES.has(source)
      ? Math.min(state.subscriptionTokenGrantRemaining, burned)
      : 0;
  const next: TokenWalletState = {
    ...state,
    snapshotPending: false,
    tokenBalance: Math.max(0, state.tokenBalance - burned),
    tokenGrantBalance: nextGrantBalance,
    subscriptionTokenGrantRemaining: Math.min(
      nextGrantBalance,
      Math.max(
        0,
        state.subscriptionTokenGrantRemaining - subscriptionBurned,
      ),
    ),
  };
  const auditRef = userRef.collection('credit_transactions').doc();
  tx.set(auditRef, {
    type: 'spend',
    amount: burned,
    unit: 'token',
    reason: BONUS_TOKEN_EXPIRY_REASON,
    source: 'bonus_expired',
    creditType: 'token_grant',
    expiredLotIds: [lot.id],
    lotSource: lot.source,
    originId: lot.originId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    remainingTokenBalance: next.tokenBalance,
    remainingTokenGrantBalance: next.tokenGrantBalance,
    remainingLegacyFlatRateRemaining: next.legacyFlatRateRemaining,
  });
  return { next, burned };
}
