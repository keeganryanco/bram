import { createClient } from "@supabase/supabase-js";
import { randomBytes } from "node:crypto";
import { fetchAccountSnapshot } from "./revenuecat";

const referralCodePattern = /^BRAM[A-Z0-9]{6,14}$/;

type DatabaseError = {
  code?: string;
  message?: string;
};

type QueryResult<T> = Promise<{ data: T; error: DatabaseError | null }>;

type ReferralFilter = {
  eq: (column: string, value: string) => ReferralFilter;
  limit: (count: number) => QueryResult<Record<string, unknown>[] | null>;
  maybeSingle: () => QueryResult<Record<string, unknown> | null>;
  single: () => QueryResult<Record<string, unknown> | null>;
};

type ReferralInsertBuilder = Promise<{ error: DatabaseError | null }>;

type SupabaseReferralClient = {
  auth: {
    getUser: (
      jwt: string,
    ) => Promise<{ data: { user: { id: string } | null }; error: unknown | null }>;
  };
  from: (table: string) => {
    select: (columns?: string) => ReferralFilter;
    insert: (values: Record<string, unknown>) => ReferralInsertBuilder;
  };
};

export class ReferralError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.name = "ReferralError";
    this.status = status;
  }
}

let supabaseAdmin: SupabaseReferralClient | null = null;

export function normalizeReferralCode(rawCode: string) {
  return rawCode.replace(/[\s-]/g, "").toUpperCase();
}

export function referralShareURL(code: string) {
  const siteURL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://www.trybram.app";
  return `${siteURL.replace(/\/$/, "")}/referral/${encodeURIComponent(code)}`;
}

export function referralFriendOfferURL() {
  if (process.env.BRAM_REFERRAL_FRIEND_OFFER_URL) {
    return process.env.BRAM_REFERRAL_FRIEND_OFFER_URL;
  }

  const appId = process.env.BRAM_APPLE_APP_ID ?? process.env.NEXT_PUBLIC_APPLE_APP_ID;
  const offerCode = process.env.BRAM_REFERRAL_FRIEND_OFFER_CODE;
  if (!appId || !offerCode) {
    return null;
  }

  return `https://apps.apple.com/redeem?ctx=offercodes&id=${encodeURIComponent(appId)}&code=${encodeURIComponent(offerCode)}`;
}

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new ReferralError("Supabase referral environment is missing.", 503);
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as SupabaseReferralClient;
  return supabaseAdmin;
}

async function userIdForToken(supabase: SupabaseReferralClient, accessToken: string) {
  const { data, error } = await supabase.auth.getUser(accessToken);
  if (error || !data.user) {
    throw new ReferralError("Unauthorized.", 401);
  }
  return data.user.id;
}

function randomReferralCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let suffix = "";
  const values = randomBytes(8);
  for (const value of values) {
    suffix += alphabet[value % alphabet.length];
  }
  return `BRAM${suffix}`;
}

async function existingCode(supabase: SupabaseReferralClient, userId: string) {
  const { data, error } = await supabase
    .from("account_referral_codes")
    .select("code")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    throw new ReferralError("Could not load referral code.");
  }

  return typeof data?.code === "string" ? data.code : null;
}

async function redemptionCount(supabase: SupabaseReferralClient, userId: string) {
  const { data, error } = await supabase
    .from("account_referral_redemptions")
    .select("id")
    .eq("referrer_user_id", userId)
    .limit(500);

  if (error) {
    throw new ReferralError("Could not load referral progress.");
  }

  return Array.isArray(data) ? data.length : 0;
}

export async function referralProgramForToken(
  accessToken: string,
  clients: { supabase?: SupabaseReferralClient } = {},
) {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const userId = await userIdForToken(supabase, accessToken);
  const current = await existingCode(supabase, userId);
  if (current) {
    return {
      code: current,
      successfulRedemptions: await redemptionCount(supabase, userId),
      shareURL: referralShareURL(current),
      friendOfferRedemptionURL: referralFriendOfferURL(),
    };
  }

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = randomReferralCode();
    const { error } = await supabase.from("account_referral_codes").insert({
      user_id: userId,
      code,
    });

    if (!error) {
      return {
        code,
        successfulRedemptions: await redemptionCount(supabase, userId),
        shareURL: referralShareURL(code),
        friendOfferRedemptionURL: referralFriendOfferURL(),
      };
    }

    if (error.code !== "23505") {
      throw new ReferralError("Could not create referral code.");
    }
  }

  throw new ReferralError("Could not create a unique referral code.");
}

function entitlementBlocksReferralReward(entitlement: Record<string, unknown> | null) {
  if (!entitlement) {
    return false;
  }

  if (entitlement.is_developer === true) {
    return true;
  }

  return (
    entitlement.active_promo_kind === "FRIENDS_DISCOUNT" ||
    entitlement.active_promo_kind === "FOUNDER_LIFETIME"
  );
}

async function insertReward(
  supabase: SupabaseReferralClient,
  values: {
    redemptionId: string;
    userId: string;
    status: "APPLIED" | "QUEUED" | "SKIPPED";
    premiumExpiresAt?: string | null;
    reason: string;
  },
) {
  const { error } = await supabase.from("account_referral_rewards").insert({
    redemption_id: values.redemptionId,
    user_id: values.userId,
    reward_kind: "REFERRAL_1MONTH",
    status: values.status,
    premium_expires_at: values.premiumExpiresAt ?? null,
    reason: values.reason,
  });

  if (error && error.code !== "23505") {
    throw new ReferralError("Could not record referral reward.");
  }
}

async function rewardReferrer(
  supabase: SupabaseReferralClient,
  referrerUserId: string,
  redemptionId: string,
) {
  const { data: entitlement, error } = await supabase
    .from("account_entitlements")
    .select("account_tier,subscription_status,entitlement_source,is_developer,active_promo_kind,premium_expires_at")
    .eq("user_id", referrerUserId)
    .single();

  if (error) {
    throw new ReferralError("Could not load referrer entitlement.");
  }

  if (entitlementBlocksReferralReward(entitlement)) {
    await insertReward(supabase, {
      redemptionId,
      userId: referrerUserId,
      status: "SKIPPED",
      reason: "Referrer already has developer, friends, or lifetime access.",
    });
    return;
  }

  await insertReward(supabase, {
    redemptionId,
    userId: referrerUserId,
    status: "QUEUED",
    reason:
      "Referrer earned a one-month reward. Deliver through an Apple subscription offer code; do not grant non-IAP app access.",
  });
}

function snapshotHasAppleSubscriptionAccess(snapshot: Record<string, unknown>) {
  const tier = snapshot.account_tier;
  const source = snapshot.entitlement_source;
  const status = snapshot.subscription_status;
  return (
    tier === "PREMIUM" &&
    (source === "APP_STORE" || source === "REVENUECAT") &&
    status !== "EXPIRED"
  );
}

export async function claimReferralCodeForToken(
  accessToken: string,
  rawCode: string,
  clients: { supabase?: SupabaseReferralClient } = {},
) {
  const code = normalizeReferralCode(rawCode);
  if (!referralCodePattern.test(code)) {
    throw new ReferralError("That promo code is not available for this account.", 404);
  }

  const supabase = clients.supabase ?? getSupabaseAdmin();
  const referredUserId = await userIdForToken(supabase, accessToken);
  const snapshot = await fetchAccountSnapshot(supabase as never, referredUserId);
  if (!snapshotHasAppleSubscriptionAccess(snapshot as Record<string, unknown>)) {
    throw new ReferralError(
      "Redeem the Apple offer code first, then return to Bram to finish the referral.",
      402,
    );
  }

  const { data: referralCode, error: codeError } = await supabase
    .from("account_referral_codes")
    .select("user_id,code")
    .eq("code", code)
    .single();

  if (codeError || !referralCode) {
    throw new ReferralError("That promo code is not available for this account.", 404);
  }

  const referrerUserId = String(referralCode.user_id);
  if (referrerUserId === referredUserId) {
    throw new ReferralError("You cannot redeem your own referral code.", 403);
  }

  const { error: grantError } = await supabase
    .from("account_referral_redemptions")
    .insert({
      referral_code: code,
      referrer_user_id: referrerUserId,
      referred_user_id: referredUserId,
    });

  if (grantError) {
    if (grantError.code === "23505") {
      throw new ReferralError("This referral has already been redeemed.", 409);
    }
    throw new ReferralError("Could not redeem referral code.");
  }

  const { data: redemption, error: redemptionError } = await supabase
    .from("account_referral_redemptions")
    .select("id")
    .eq("referral_code", code)
    .eq("referred_user_id", referredUserId)
    .single();

  if (redemptionError || typeof redemption?.id !== "string") {
    throw new ReferralError("Could not record referral redemption.");
  }

  await rewardReferrer(supabase, referrerUserId, redemption.id);

  return snapshot;
}
