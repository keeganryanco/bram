import { describe, expect, it, vi } from "vitest";
import {
  handleRevenueCatWebhook,
  refreshRevenueCatEntitlementForToken,
  syncRevenueCatEntitlement,
  verifyRevenueCatWebhookAuth,
} from "./revenuecat";

const userId = "11111111-1111-4111-8111-111111111111";

function revenueCatFetch(options: {
  active?: boolean;
  unsubscribeDetectedAt?: string | null;
  billingIssuesDetectedAt?: string | null;
} = {}) {
  const active = options.active ?? true;
  return vi.fn(async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      subscriber: {
        entitlements: active
          ? {
              premium: {
                product_identifier: "app.trybram.Bram.premium.year",
                expires_date: "2099-01-01T00:00:00Z",
              },
            }
          : {},
        subscriptions: {
          "app.trybram.Bram.premium.year": {
            period_type: "TRIAL",
            expires_date: "2099-01-01T00:00:00Z",
            unsubscribe_detected_at: options.unsubscribeDetectedAt,
            billing_issues_detected_at: options.billingIssuesDetectedAt,
          },
        },
      },
    }),
  })) as unknown as typeof fetch;
}

function supabaseMock(options: {
  authUser?: string | null;
  entitlementSource?: string;
  accountTier?: string;
  isDeveloper?: boolean;
  premiumExpiresAt?: string | null;
} = {}) {
  const calls: { table: string; operation: string; values?: unknown }[] = [];
  const state = {
    entitlementSource: options.entitlementSource ?? "NONE",
    accountTier: options.accountTier ?? "FREE",
    isDeveloper: options.isDeveloper ?? false,
  };

  return {
    calls,
    auth: {
      getUser: vi.fn(async () =>
        options.authUser === null
          ? { data: { user: null }, error: { message: "bad token" } }
          : { data: { user: { id: options.authUser ?? userId } }, error: null },
      ),
    },
    from: vi.fn((table: string) => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          single: vi.fn(async () => {
            if (table === "account_entitlements") {
              return {
                data: {
                  account_tier: state.accountTier,
                  entitlement_source: state.entitlementSource,
                  is_developer: state.isDeveloper,
                  premium_expires_at: options.premiumExpiresAt ?? null,
                },
                error: null,
              };
            }

            return {
              data: {
                user_id: userId,
                email: "paid@trybram.app",
                display_name: "Paid",
                preferred_units: "lb",
                onboarding_completed_at: "2026-05-13T12:00:00Z",
                account_tier: state.accountTier,
                subscription_status: "TRIAL",
                entitlement_source: state.entitlementSource,
                is_developer: state.isDeveloper,
                founder_offer_eligible: false,
                premium_expires_at: "2099-01-01T00:00:00Z",
                entitlements_updated_at: "2026-05-13T12:00:00Z",
              },
              error: null,
            };
          }),
        })),
      })),
      update: vi.fn((values: Record<string, unknown>) => {
        calls.push({ table, operation: "update", values });
        state.accountTier = values.account_tier as string;
        state.entitlementSource = values.entitlement_source as string;
        return {
          eq: vi.fn(async () => ({ error: null })),
        };
      }),
      upsert: vi.fn(async (values: unknown) => {
        calls.push({ table, operation: "upsert", values });
        return { error: null };
      }),
      insert: vi.fn(async (values: unknown) => {
        calls.push({ table, operation: "insert", values });
        return { error: null };
      }),
    })),
  };
}

describe("verifyRevenueCatWebhookAuth", () => {
  it("accepts the configured webhook authorization header", () => {
    vi.stubEnv("REVENUECAT_WEBHOOK_AUTH_HEADER", "Bearer webhook_secret");
    const request = new Request("https://trybram.app/api/revenuecat/webhook", {
      headers: { authorization: "Bearer webhook_secret" },
    });

    expect(verifyRevenueCatWebhookAuth(request)).toBe(true);
    vi.unstubAllEnvs();
  });

  it("rejects a missing or wrong webhook authorization header", () => {
    vi.stubEnv("REVENUECAT_WEBHOOK_AUTH_HEADER", "Bearer webhook_secret");
    const request = new Request("https://trybram.app/api/revenuecat/webhook", {
      headers: { authorization: "Bearer wrong" },
    });

    expect(verifyRevenueCatWebhookAuth(request)).toBe(false);
    vi.unstubAllEnvs();
  });
});

describe("refreshRevenueCatEntitlementForToken", () => {
  it("rejects an invalid Supabase session", async () => {
    const supabase = supabaseMock({ authUser: null });

    await expect(
      refreshRevenueCatEntitlementForToken("bad-token", {
        supabase,
        fetch: revenueCatFetch(),
      }),
    ).rejects.toThrow("Invalid Supabase session.");
  });

  it("updates entitlements from active RevenueCat premium state", async () => {
    vi.stubEnv("REVENUECAT_SECRET_API_KEY", "rc_secret");
    const supabase = supabaseMock();

    await refreshRevenueCatEntitlementForToken("good-token", {
      supabase,
      fetch: revenueCatFetch(),
    });

    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "account_entitlements",
        operation: "update",
        values: expect.objectContaining({
          account_tier: "PREMIUM",
          subscription_status: "TRIAL",
          entitlement_source: "REVENUECAT",
        }),
      }),
    );
    vi.unstubAllEnvs();
  });
});

describe("handleRevenueCatWebhook", () => {
  it("inserts webhook events idempotently and syncs current entitlement state", async () => {
    vi.stubEnv("REVENUECAT_SECRET_API_KEY", "rc_secret");
    const supabase = supabaseMock();

    await handleRevenueCatWebhook(
      {
        event: {
          id: "event_123",
          type: "INITIAL_PURCHASE",
          app_user_id: userId,
          product_id: "app.trybram.Bram.premium.year",
          transaction_id: "tx_123",
          original_transaction_id: "otx_123",
          entitlement_ids: ["premium"],
          purchased_at_ms: 1_777_777_777_000,
          expiration_at_ms: 4_071_398_400_000,
        },
      },
      { supabase, fetch: revenueCatFetch() },
    );

    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "subscription_events",
        operation: "upsert",
        values: expect.objectContaining({
          provider: "REVENUECAT",
          provider_event_id: "event_123",
          event_type: "INITIAL_PURCHASE",
        }),
      }),
    );
    vi.unstubAllEnvs();
  });

  it("does not accept client supplied entitlement values", async () => {
    vi.stubEnv("REVENUECAT_SECRET_API_KEY", "rc_secret");
    const supabase = supabaseMock();

    await syncRevenueCatEntitlement(userId, {
      supabase,
      fetch: revenueCatFetch({ active: false }),
    });

    expect(supabase.calls).not.toContainEqual(
      expect.objectContaining({
        values: expect.objectContaining({ account_tier: "PREMIUM" }),
      }),
    );
    vi.unstubAllEnvs();
  });

  it("maps canceled-but-active subscriptions without removing access", async () => {
    vi.stubEnv("REVENUECAT_SECRET_API_KEY", "rc_secret");
    const supabase = supabaseMock();

    await syncRevenueCatEntitlement(userId, {
      supabase,
      fetch: revenueCatFetch({ unsubscribeDetectedAt: "2026-05-15T12:00:00Z" }),
    });

    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "account_entitlements",
        operation: "update",
        values: expect.objectContaining({
          account_tier: "PREMIUM",
          subscription_status: "CANCELED",
        }),
      }),
    );
    vi.unstubAllEnvs();
  });

  it("maps billing issues to billing retry while access is active", async () => {
    vi.stubEnv("REVENUECAT_SECRET_API_KEY", "rc_secret");
    const supabase = supabaseMock();

    await syncRevenueCatEntitlement(userId, {
      supabase,
      fetch: revenueCatFetch({ billingIssuesDetectedAt: "2026-05-15T12:00:00Z" }),
    });

    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "account_entitlements",
        operation: "update",
        values: expect.objectContaining({
          account_tier: "PREMIUM",
          subscription_status: "BILLING_RETRY",
        }),
      }),
    );
    vi.unstubAllEnvs();
  });

  it("preserves active manual grants when RevenueCat is expired", async () => {
    vi.stubEnv("REVENUECAT_SECRET_API_KEY", "rc_secret");
    const supabase = supabaseMock({
      accountTier: "FREE_PREMIUM",
      entitlementSource: "MANUAL",
      premiumExpiresAt: "2099-01-01T00:00:00Z",
    });

    await syncRevenueCatEntitlement(userId, {
      supabase,
      fetch: revenueCatFetch({ active: false }),
    });

    expect(supabase.calls).not.toContainEqual(
      expect.objectContaining({
        table: "account_entitlements",
        operation: "update",
        values: expect.objectContaining({ account_tier: "FREE" }),
      }),
    );
    vi.unstubAllEnvs();
  });

  it("expires expired manual grants when RevenueCat is expired", async () => {
    vi.stubEnv("REVENUECAT_SECRET_API_KEY", "rc_secret");
    const supabase = supabaseMock({
      accountTier: "FREE_PREMIUM",
      entitlementSource: "MANUAL",
      premiumExpiresAt: "2020-01-01T00:00:00Z",
    });

    await syncRevenueCatEntitlement(userId, {
      supabase,
      fetch: revenueCatFetch({ active: false }),
    });

    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "account_entitlements",
        operation: "update",
        values: expect.objectContaining({
          account_tier: "FREE",
          subscription_status: "EXPIRED",
          entitlement_source: "NONE",
        }),
      }),
    );
    vi.unstubAllEnvs();
  });
});
