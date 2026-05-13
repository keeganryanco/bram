import { createClient } from "@supabase/supabase-js";
import { z } from "zod";

const premiumEntitlementId = "premium";

const revenueCatEventSchema = z.object({
  id: z.string().optional(),
  type: z.string().optional(),
  app_user_id: z.string().optional(),
  original_app_user_id: z.string().optional(),
  aliases: z.array(z.string()).optional(),
  product_id: z.string().optional().nullable(),
  transaction_id: z.string().optional().nullable(),
  original_transaction_id: z.string().optional().nullable(),
  purchased_at_ms: z.number().optional().nullable(),
  expiration_at_ms: z.number().optional().nullable(),
  entitlement_ids: z.array(z.string()).optional().nullable(),
  period_type: z.string().optional().nullable(),
});

const revenueCatWebhookSchema = z.object({
  api_version: z.string().optional(),
  event: revenueCatEventSchema,
});

type RevenueCatEvent = z.infer<typeof revenueCatEventSchema>;

type RevenueCatEntitlement = {
  expires_date?: string | null;
  product_identifier?: string | null;
};

type RevenueCatSubscription = {
  period_type?: string | null;
  expires_date?: string | null;
};

type RevenueCatSubscriberResponse = {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlement | undefined>;
    subscriptions?: Record<string, RevenueCatSubscription | undefined>;
  };
};

type QueryResult<T> = Promise<{ data: T; error: unknown | null }>;

type SupabaseLike = {
  auth: {
    getUser: (
      jwt: string,
    ) => Promise<{ data: { user: { id: string } | null }; error: unknown | null }>;
  };
  from: (table: string) => {
    select: (columns?: string) => {
      eq: (column: string, value: string) => {
        single: () => QueryResult<unknown>;
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

type RevenueCatClients = {
  supabase?: SupabaseLike;
  fetch?: typeof fetch;
};

export class RevenueCatConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RevenueCatConfigError";
  }
}

let supabaseAdmin: SupabaseLike | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new RevenueCatConfigError("Supabase RevenueCat environment is missing.");
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as SupabaseLike;

  return supabaseAdmin;
}

function getRevenueCatAPIKey() {
  const apiKey = process.env.REVENUECAT_SECRET_API_KEY;
  if (!apiKey) {
    throw new RevenueCatConfigError("RevenueCat API key is missing.");
  }
  return apiKey;
}

function msToISOString(value: number | null | undefined) {
  return typeof value === "number" ? new Date(value).toISOString() : null;
}

function isActive(expiresDate: string | null | undefined) {
  if (!expiresDate) {
    return true;
  }
  return new Date(expiresDate).getTime() > Date.now();
}

function subscriptionStatus(
  active: boolean,
  entitlement: RevenueCatEntitlement | undefined,
  subscription: RevenueCatSubscription | undefined,
) {
  if (!active) {
    return "EXPIRED";
  }

  return subscription?.period_type?.toUpperCase() === "TRIAL" ? "TRIAL" : "ACTIVE";
}

async function fetchRevenueCatSubscriber(
  appUserId: string,
  fetchImpl: typeof fetch,
) {
  const response = await fetchImpl(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
    {
      headers: {
        Authorization: `Bearer ${getRevenueCatAPIKey()}`,
        "Content-Type": "application/json",
      },
    },
  );

  if (!response.ok) {
    throw new Error(`RevenueCat subscriber fetch failed with ${response.status}.`);
  }

  return (await response.json()) as RevenueCatSubscriberResponse;
}

async function currentAccountEntitlement(supabase: SupabaseLike, userId: string) {
  const { data, error } = await supabase
    .from("account_entitlements")
    .select("account_tier, entitlement_source, is_developer")
    .eq("user_id", userId)
    .single();

  if (error) {
    throw error;
  }

  return data as {
    account_tier: string;
    entitlement_source: string;
    is_developer: boolean;
  };
}

export async function syncRevenueCatEntitlement(
  appUserId: string,
  clients: RevenueCatClients = {},
) {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const fetchImpl = clients.fetch ?? fetch;
  const subscriber = await fetchRevenueCatSubscriber(appUserId, fetchImpl);
  const entitlement =
    subscriber.subscriber?.entitlements?.[premiumEntitlementId] ?? undefined;
  const productId = entitlement?.product_identifier ?? undefined;
  const subscription = productId
    ? subscriber.subscriber?.subscriptions?.[productId]
    : undefined;
  const active = Boolean(entitlement && isActive(entitlement.expires_date));
  const existing = await currentAccountEntitlement(supabase, appUserId);

  if (
    !active &&
    (existing.is_developer ||
      existing.account_tier === "FREE_PREMIUM" ||
      !["REVENUECAT", "APP_STORE"].includes(existing.entitlement_source))
  ) {
    return fetchAccountSnapshot(supabase, appUserId);
  }

  const update = active
    ? {
        account_tier: "PREMIUM",
        subscription_status: subscriptionStatus(active, entitlement, subscription),
        entitlement_source: "REVENUECAT",
        revenuecat_app_user_id: appUserId,
        premium_expires_at: entitlement?.expires_date ?? null,
      }
    : {
        account_tier: "FREE",
        subscription_status: "EXPIRED",
        entitlement_source: "NONE",
        revenuecat_app_user_id: appUserId,
        premium_expires_at: null,
      };

  const { error } = await supabase
    .from("account_entitlements")
    .update(update)
    .eq("user_id", appUserId);

  if (error) {
    throw error;
  }

  return fetchAccountSnapshot(supabase, appUserId);
}

export async function fetchAccountSnapshot(
  supabase: SupabaseLike,
  userId: string,
) {
  const { data, error } = await supabase
    .from("account_snapshot")
    .select()
    .eq("user_id", userId)
    .single();

  if (error) {
    throw error;
  }

  return data;
}

export async function refreshRevenueCatEntitlementForToken(
  accessToken: string,
  clients: RevenueCatClients = {},
) {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const { data, error } = await supabase.auth.getUser(accessToken);

  if (error || !data.user) {
    throw new Error("Invalid Supabase session.");
  }

  return syncRevenueCatEntitlement(data.user.id, { ...clients, supabase });
}

export function verifyRevenueCatWebhookAuth(request: Request) {
  const expected = process.env.REVENUECAT_WEBHOOK_AUTH_HEADER;
  if (!expected) {
    throw new RevenueCatConfigError("RevenueCat webhook auth header is missing.");
  }
  return request.headers.get("authorization") === expected;
}

export async function handleRevenueCatWebhook(
  body: unknown,
  clients: RevenueCatClients = {},
) {
  const payload = revenueCatWebhookSchema.parse(body);
  const event = payload.event;
  const appUserId = event.app_user_id ?? event.original_app_user_id;

  if (!appUserId || !z.string().uuid().safeParse(appUserId).success) {
    return { ignored: true };
  }

  const supabase = clients.supabase ?? getSupabaseAdmin();
  await insertSubscriptionEvent(supabase, appUserId, event);
  const account = await syncRevenueCatEntitlement(appUserId, { ...clients, supabase });
  return { ignored: false, account };
}

async function insertSubscriptionEvent(
  supabase: SupabaseLike,
  userId: string,
  event: RevenueCatEvent,
) {
  const values = {
    user_id: userId,
    provider: "REVENUECAT",
    provider_event_id: event.id ?? null,
    event_type: event.type ?? "UNKNOWN",
    product_id: event.product_id ?? null,
    original_transaction_id: event.original_transaction_id ?? null,
    transaction_id: event.transaction_id ?? null,
    purchased_at: msToISOString(event.purchased_at_ms),
    expires_at: msToISOString(event.expiration_at_ms),
    raw_event: event,
  };

  const { error } = event.id
    ? await supabase.from("subscription_events").upsert(values, {
        onConflict: "provider,provider_event_id",
        ignoreDuplicates: true,
      })
    : await supabase.from("subscription_events").insert(values);

  if (error) {
    throw error;
  }
}
