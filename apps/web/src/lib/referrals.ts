import { createClient } from "@supabase/supabase-js";
import { randomBytes } from "node:crypto";
import { grantAccountAccess } from "./account-grants";
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
      };
    }

    if (error.code !== "23505") {
      throw new ReferralError("Could not create referral code.");
    }
  }

  throw new ReferralError("Could not create a unique referral code.");
}

function addOneMonth(date: Date) {
  const value = new Date(date);
  value.setUTCMonth(value.getUTCMonth() + 1);
  return value;
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

function paidAccessIsActive(entitlement: Record<string, unknown> | null) {
  return (
    entitlement?.account_tier === "PREMIUM" &&
    (entitlement.entitlement_source === "APP_STORE" ||
      entitlement.entitlement_source === "REVENUECAT")
  );
}

function currentPremiumExpiration(entitlement: Record<string, unknown> | null) {
  const raw = entitlement?.premium_expires_at;
  if (typeof raw !== "string") {
    return null;
  }
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? null : date;
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

  if (paidAccessIsActive(entitlement)) {
    await insertReward(supabase, {
      redemptionId,
      userId: referrerUserId,
      status: "QUEUED",
      reason: "Referrer has active App Store access; Bram-owned credit is queued.",
    });
    return;
  }

  const now = new Date();
  const currentExpiration = currentPremiumExpiration(entitlement);
  const rewardStart =
    currentExpiration && currentExpiration > now ? currentExpiration : now;
  const premiumExpiresAt = addOneMonth(rewardStart).toISOString();

  await grantAccountAccess(
    {
      userId: referrerUserId,
      grantKind: "REFERRAL_1MONTH",
      premiumExpiresAt,
      reason: "Earned one month by sharing Bram with a friend.",
      createdBy: "referral-redemption",
    },
    { supabase: supabase as never },
  );

  await insertReward(supabase, {
    redemptionId,
    userId: referrerUserId,
    status: "APPLIED",
    premiumExpiresAt,
    reason: "Referral reward applied.",
  });
}

export async function redeemReferralCodeForToken(
  accessToken: string,
  rawCode: string,
  clients: { supabase?: SupabaseReferralClient } = {},
) {
  const code = rawCode.replace(/[\s-]/g, "").toUpperCase();
  if (!referralCodePattern.test(code)) {
    throw new ReferralError("That promo code is not available for this account.", 404);
  }

  const supabase = clients.supabase ?? getSupabaseAdmin();
  const referredUserId = await userIdForToken(supabase, accessToken);
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

  await grantAccountAccess(
    {
      userId: referredUserId,
      grantKind: "REFERRAL_1MONTH",
      reason: `Redeemed referral code ${code}.`,
      createdBy: "referral-redemption",
    },
    { supabase: supabase as never },
  );
  await rewardReferrer(supabase, referrerUserId, redemption.id);

  return fetchAccountSnapshot(supabase as never, referredUserId);
}
