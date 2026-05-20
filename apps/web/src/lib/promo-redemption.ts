import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { grantAccountAccess } from "./account-grants";
import { sendTestFlightWelcomeEmail } from "./launch-emails";
import { redeemReferralCodeForToken, ReferralError } from "./referrals";
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
  },
  PRODUCTHUNT1MONTH: {
    grantKind: "PRODUCT_HUNT_1MONTH",
  },
  FOUNDER1MONTH: {
    grantKind: "FOUNDER_1MONTH",
    requiresFounderEligibility: true,
  },
} as const;

type PromoCode = keyof typeof promoCodes;

type SupabasePromoFilter = {
  eq: (column: string, value: string | boolean) => SupabasePromoFilter;
  in: (column: string, values: string[]) => SupabasePromoFilter;
  is: (column: string, value: null) => SupabasePromoFilter;
  or: (filters: string) => SupabasePromoFilter;
  order: (column: string, options?: { ascending?: boolean }) => SupabasePromoFilter;
  limit: (count: number) => Promise<{ data: Record<string, unknown>[] | null; error: unknown | null }>;
  maybeSingle: () => Promise<{ data: Record<string, unknown> | null; error: unknown | null }>;
  single: () => Promise<{ data: Record<string, unknown> | null; error: unknown | null }>;
};

type SupabasePromoClient = {
  auth: {
    getUser: (
      jwt: string,
    ) => Promise<{ data: { user: { id: string } | null }; error: unknown | null }>;
  };
  from: (table: string) => {
    select: (columns?: string) => SupabasePromoFilter;
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

type ResendLike = {
  emails: {
    send: (values: {
      from: string;
      to: string;
      subject: string;
      text: string;
      html?: string;
    }) => Promise<unknown>;
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

export async function redeemPromoCodeForToken(
  accessToken: string,
  rawCode: string,
  clients: { supabase?: SupabasePromoClient; resend?: ResendLike } = {},
) {
  const code = PromoCodeSchema.parse(rawCode);
  if (!(code in promoCodes)) {
    try {
      return await redeemReferralCodeForToken(accessToken, code, {
        supabase: clients.supabase as never,
      });
    } catch (error) {
      if (error instanceof ReferralError) {
        throw new PromoRedemptionError(error.message, error.status);
      }
      throw error;
    }
  }
  assertKnownPromo(code);

  const supabase = clients.supabase ?? getSupabaseAdmin();
  const { data, error } = await supabase.auth.getUser(accessToken);
  if (error || !data.user) {
    throw new PromoRedemptionError("Unauthorized.", 401);
  }

  const userId = data.user.id;
  const { email } = await profileForUser(supabase, userId);
  const promo = promoCodes[code];

  if ("requiresFounderEligibility" in promo) {
    const eligible = await hasFounderEligibility(supabase, userId, email);
    if (!eligible) {
      throw new PromoRedemptionError("That promo code is not available for this account.", 403);
    }
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

  if (code === "TESTFLIGHT1MONTH") {
    try {
      await sendTestFlightWelcomeEmail(
        { userId, email },
        { supabase, resend: clients.resend },
      );
    } catch (error) {
      console.error("testflight_welcome_email_failed", error);
    }
  }

  return fetchAccountSnapshot(supabase, userId);
}
