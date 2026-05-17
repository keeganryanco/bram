import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { grantAccountAccess } from "./account-grants";
import { fetchAccountSnapshot } from "./revenuecat";

const PromoCodeSchema = z
  .string()
  .trim()
  .min(3)
  .max(40)
  .transform((value) => value.replace(/[\s-]/g, "").toUpperCase());

const promoCodes = {
  TESTFLIGHT1MONTH: {
    grantKind: "TESTFLIGHT_1MONTH",
    requiresAllowlist: true,
  },
  PRODUCTHUNT1MONTH: {
    grantKind: "PRODUCT_HUNT_1MONTH",
    requiresAllowlist: true,
  },
  FOUNDER1MONTH: {
    grantKind: "FOUNDER_1MONTH",
    requiresFounderEligibility: true,
  },
} as const;

type PromoCode = keyof typeof promoCodes;

type SupabasePromoClient = {
  auth: {
    getUser: (
      jwt: string,
    ) => Promise<{ data: { user: { id: string } | null }; error: unknown | null }>;
  };
  from: (table: string) => {
    select: (columns?: string) => {
      eq: (column: string, value: string) => {
        single: () => Promise<{ data: Record<string, unknown> | null; error: unknown | null }>;
        eq: (column: string, value: string) => {
          limit: (count: number) => Promise<{ data: Record<string, unknown>[] | null; error: unknown | null }>;
        };
        or: (filters: string) => {
          limit: (count: number) => Promise<{ data: Record<string, unknown>[] | null; error: unknown | null }>;
        };
        limit: (count: number) => Promise<{ data: Record<string, unknown>[] | null; error: unknown | null }>;
      };
    };
    update: (values: Record<string, unknown>) => {
      eq: (column: string, value: string) => Promise<{ error: unknown | null }>;
    };
    upsert: (
      values: Record<string, unknown>,
      options?: { onConflict?: string; ignoreDuplicates?: boolean },
    ) => Promise<{ error: unknown | null }>;
    insert: (values: Record<string, unknown>) => Promise<{ error: unknown | null }>;
  };
};

export class PromoRedemptionError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.name = "PromoRedemptionError";
    this.status = status;
  }
}

let supabaseAdmin: SupabasePromoClient | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new PromoRedemptionError("Supabase promo environment is missing.", 503);
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as SupabasePromoClient;
  return supabaseAdmin;
}

function assertKnownPromo(code: string): asserts code is PromoCode {
  if (!(code in promoCodes)) {
    throw new PromoRedemptionError("That promo code is not available for this account.", 404);
  }
}

async function profileForUser(supabase: SupabasePromoClient, userId: string) {
  const { data, error } = await supabase
    .from("profiles")
    .select("email")
    .eq("user_id", userId)
    .single();

  if (error || !data?.email) {
    throw new PromoRedemptionError("Account profile was not found.", 404);
  }

  return { email: String(data.email).toLowerCase() };
}

async function hasFounderEligibility(
  supabase: SupabasePromoClient,
  userId: string,
  email: string,
) {
  const { data: entitlement } = await supabase
    .from("account_entitlements")
    .select("founder_offer_eligible")
    .eq("user_id", userId)
    .single();

  if (entitlement?.founder_offer_eligible === true) {
    return true;
  }

  const { data: waitlist } = await supabase
    .from("waitlist_signups")
    .select("id")
    .eq("email", email)
    .or("founder_offer_eligible.eq.true,founder_discount_eligible.eq.true")
    .limit(1);

  return Array.isArray(waitlist) && waitlist.length > 0;
}

async function findAllowlistEligibility(
  supabase: SupabasePromoClient,
  userId: string,
  email: string,
  code: string,
) {
  const selectColumns = "id, expires_at, redeemed_at, grant_kind";
  const byUser = await supabase
    .from("account_promo_eligibilities")
    .select(selectColumns)
    .eq("user_id", userId)
    .eq("promo_code", code)
    .limit(1);

  const byEmail = await supabase
    .from("account_promo_eligibilities")
    .select(selectColumns)
    .eq("email", email)
    .eq("promo_code", code)
    .limit(1);

  const row = [...(byUser.data ?? []), ...(byEmail.data ?? [])][0];
  if (!row || byUser.error || byEmail.error) {
    return null;
  }

  if (row.redeemed_at) {
    throw new PromoRedemptionError("That promo code has already been redeemed.", 409);
  }

  const expiresAt = typeof row.expires_at === "string" ? row.expires_at : null;
  if (expiresAt && new Date(expiresAt).getTime() <= Date.now()) {
    throw new PromoRedemptionError("That promo code has expired.", 410);
  }

  return row as { id: string; grant_kind: string };
}

export async function redeemPromoCodeForToken(
  accessToken: string,
  rawCode: string,
  clients: { supabase?: SupabasePromoClient } = {},
) {
  const code = PromoCodeSchema.parse(rawCode);
  assertKnownPromo(code);

  const supabase = clients.supabase ?? getSupabaseAdmin();
  const { data, error } = await supabase.auth.getUser(accessToken);
  if (error || !data.user) {
    throw new PromoRedemptionError("Unauthorized.", 401);
  }

  const userId = data.user.id;
  const { email } = await profileForUser(supabase, userId);
  const promo = promoCodes[code];
  let eligibilityId: string | null = null;

  if ("requiresFounderEligibility" in promo) {
    const eligible = await hasFounderEligibility(supabase, userId, email);
    if (!eligible) {
      throw new PromoRedemptionError("That promo code is not available for this account.", 403);
    }
  }

  if ("requiresAllowlist" in promo) {
    const eligibility = await findAllowlistEligibility(supabase, userId, email, code);
    if (!eligibility) {
      throw new PromoRedemptionError("That promo code is not available for this account.", 403);
    }
    eligibilityId = eligibility.id;
  }

  await grantAccountAccess(
    {
      userId,
      grantKind: promo.grantKind,
      reason: `Redeemed ${code}.`,
      createdBy: "promo-redemption",
    },
    { supabase },
  );

  if (eligibilityId) {
    await supabase
      .from("account_promo_eligibilities")
      .update({ redeemed_by_user_id: userId, redeemed_at: new Date().toISOString() })
      .eq("id", eligibilityId);
  }

  return fetchAccountSnapshot(supabase, userId);
}
