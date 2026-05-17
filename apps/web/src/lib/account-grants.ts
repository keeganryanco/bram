import { createClient } from "@supabase/supabase-js";
import { z } from "zod";

export const AccountGrantKindSchema = z.enum([
  "TESTFLIGHT",
  "PRODUCT_HUNT",
  "TESTFLIGHT_1MONTH",
  "PRODUCT_HUNT_1MONTH",
  "FOUNDER_1MONTH",
  "FOUNDER_LIFETIME",
  "FRIENDS_DISCOUNT",
]);

export const AccountGrantRequestSchema = z
  .object({
    userId: z.string().uuid().optional(),
    email: z.string().email().optional(),
    grantKind: AccountGrantKindSchema,
    premiumExpiresAt: z.string().datetime().nullable().optional(),
    aiSoftCapCents: z.number().int().positive().optional(),
    aiHardCapCents: z.number().int().positive().optional(),
    reason: z.string().max(240).optional(),
    createdBy: z.string().max(120).optional(),
  })
  .refine((value) => value.userId || value.email, {
    message: "Provide userId or email.",
  })
  .refine(
    (value) =>
      value.aiSoftCapCents === undefined ||
      value.aiHardCapCents === undefined ||
      value.aiSoftCapCents <= value.aiHardCapCents,
    {
      message: "AI soft cap must be less than or equal to hard cap.",
    },
  );

export type AccountGrantRequest = z.infer<typeof AccountGrantRequestSchema>;

type QueryResult<T> = Promise<{ data: T; error: unknown | null }>;

type SupabaseGrantClient = {
  from: (table: string) => {
    select: (columns?: string) => {
      eq: (column: string, value: string) => {
        single: () => QueryResult<unknown>;
      };
    };
    update: (values: Record<string, unknown>) => {
      eq: (column: string, value: string) => Promise<{ error: unknown | null }>;
    };
    insert: (values: Record<string, unknown>) => Promise<{ error: unknown | null }>;
  };
};

export class AccountGrantError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.name = "AccountGrantError";
    this.status = status;
  }
}

let supabaseAdmin: SupabaseGrantClient | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new AccountGrantError("Supabase admin environment is missing.", 503);
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as SupabaseGrantClient;
  return supabaseAdmin;
}

export function verifyAdminGrantToken(
  request: Request,
  env: Record<string, string | undefined> = process.env,
) {
  const expected = env.BRAM_ADMIN_GRANT_TOKEN;
  if (!expected) {
    throw new AccountGrantError("Admin grant token is not configured.", 503);
  }

  const authorization = request.headers.get("authorization");
  const bearer = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  return bearer === expected || request.headers.get("x-bram-admin-token") === expected;
}

function oneMonthFromNow(now = new Date()) {
  const value = new Date(now);
  value.setUTCMonth(value.getUTCMonth() + 1);
  return value.toISOString();
}

function canonicalGrantKind(grantKind: z.infer<typeof AccountGrantKindSchema>) {
  switch (grantKind) {
    case "TESTFLIGHT":
      return "TESTFLIGHT_1MONTH";
    case "PRODUCT_HUNT":
      return "PRODUCT_HUNT_1MONTH";
    default:
      return grantKind;
  }
}

function defaultExpiration(grantKind: z.infer<typeof AccountGrantKindSchema>) {
  const canonical = canonicalGrantKind(grantKind);
  return canonical === "FOUNDER_LIFETIME" || canonical === "FRIENDS_DISCOUNT"
    ? null
    : oneMonthFromNow();
}

function entitlementSource(grantKind: z.infer<typeof AccountGrantKindSchema>) {
  const canonical = canonicalGrantKind(grantKind);
  return canonical === "FOUNDER_LIFETIME" || canonical === "FOUNDER_1MONTH"
    ? "FOUNDER_OFFER"
    : "MANUAL";
}

function promoCode(grantKind: string) {
  switch (grantKind) {
    case "TESTFLIGHT_1MONTH":
      return "TESTFLIGHT1MONTH";
    case "PRODUCT_HUNT_1MONTH":
      return "PRODUCTHUNT1MONTH";
    case "FOUNDER_1MONTH":
      return "FOUNDER1MONTH";
    case "FOUNDER_LIFETIME":
      return "FOUNDERLIFETIME";
    case "FRIENDS_DISCOUNT":
      return "FRIENDS";
    default:
      return null;
  }
}

function promoLabel(grantKind: string) {
  switch (grantKind) {
    case "TESTFLIGHT_1MONTH":
      return "TestFlight month";
    case "PRODUCT_HUNT_1MONTH":
      return "Product Hunt month";
    case "FOUNDER_1MONTH":
      return "Founder month";
    case "FOUNDER_LIFETIME":
      return "Founder lifetime";
    case "FRIENDS_DISCOUNT":
      return "Friends access";
    default:
      return null;
  }
}

async function resolveUserId(
  supabase: SupabaseGrantClient,
  request: AccountGrantRequest,
) {
  if (request.userId) {
    return request.userId;
  }

  const email = request.email?.toLowerCase();
  if (!email) {
    throw new AccountGrantError("Provide userId or email.", 400);
  }

  const { data, error } = await supabase
    .from("profiles")
    .select("user_id")
    .eq("email", email)
    .single();

  if (error || !data || typeof data !== "object" || !("user_id" in data)) {
    throw new AccountGrantError("Account not found.", 404);
  }

  return String(data.user_id);
}

export async function grantAccountAccess(
  input: AccountGrantRequest,
  clients: { supabase?: SupabaseGrantClient } = {},
) {
  const request = AccountGrantRequestSchema.parse(input);
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const userId = await resolveUserId(supabase, request);
  const grantKind = canonicalGrantKind(request.grantKind);
  const source = entitlementSource(grantKind);
  const premiumExpiresAt =
    request.premiumExpiresAt === undefined
      ? defaultExpiration(grantKind)
      : request.premiumExpiresAt;
  const reason =
    request.reason ??
    (grantKind === "FOUNDER_LIFETIME"
      ? "Founder lifetime grant."
      : grantKind === "FRIENDS_DISCOUNT"
        ? "Friends access grant."
        : `${grantKind} grant.`);
  const update = {
    account_tier: "FREE_PREMIUM",
    subscription_status: "FREE_PREMIUM",
    entitlement_source: source,
    premium_expires_at: premiumExpiresAt,
    active_promo_kind: grantKind,
    active_promo_code: promoCode(grantKind),
    active_promo_label: promoLabel(grantKind),
    manual_reason: reason,
    ...(grantKind === "FOUNDER_LIFETIME" || grantKind === "FOUNDER_1MONTH"
      ? { founder_offer_redeemed_at: new Date().toISOString() }
      : {}),
  };

  const { error: updateError } = await supabase
    .from("account_entitlements")
    .update(update)
    .eq("user_id", userId);

  if (updateError) {
    throw new AccountGrantError("Could not grant account access.");
  }

  const { error: insertError } = await supabase.from("account_grant_events").insert({
    user_id: userId,
    grant_kind: grantKind,
    entitlement_source: source,
    premium_expires_at: premiumExpiresAt,
    ai_soft_cap_cents: request.aiSoftCapCents ?? 50,
    ai_hard_cap_cents: request.aiHardCapCents ?? 200,
    reason,
    created_by: request.createdBy ?? "admin-route",
  });

  if (insertError) {
    throw new AccountGrantError("Could not record account grant.");
  }

  return {
    userId,
    grantKind,
    entitlementSource: source,
    premiumExpiresAt,
  };
}
