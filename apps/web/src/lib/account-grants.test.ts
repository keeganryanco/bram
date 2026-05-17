import { describe, expect, it, vi } from "vitest";
import {
  grantAccountAccess,
  verifyAdminGrantToken,
} from "./account-grants";

const userId = "11111111-1111-4111-8111-111111111111";

function supabaseMock() {
  const calls: { table: string; operation: string; values?: unknown }[] = [];

  return {
    calls,
    from: vi.fn((table: string) => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          single: vi.fn(async () => ({
            data: { user_id: userId },
            error: null,
          })),
        })),
      })),
      update: vi.fn((values: Record<string, unknown>) => {
        calls.push({ table, operation: "update", values });
        return {
          eq: vi.fn(async () => ({ error: null })),
        };
      }),
      insert: vi.fn(async (values: Record<string, unknown>) => {
        calls.push({ table, operation: "insert", values });
        return { error: null };
      }),
    })),
  };
}

describe("verifyAdminGrantToken", () => {
  it("accepts the configured bearer token", () => {
    const request = new Request("https://trybram.app/api/admin/account-grants", {
      headers: { authorization: "Bearer admin-secret" },
    });

    expect(
      verifyAdminGrantToken(request, { BRAM_ADMIN_GRANT_TOKEN: "admin-secret" }),
    ).toBe(true);
  });

  it("rejects the wrong token", () => {
    const request = new Request("https://trybram.app/api/admin/account-grants", {
      headers: { authorization: "Bearer wrong" },
    });

    expect(
      verifyAdminGrantToken(request, { BRAM_ADMIN_GRANT_TOKEN: "admin-secret" }),
    ).toBe(false);
  });
});

describe("grantAccountAccess", () => {
  it("creates a one-month manual grant for Product Hunt users", async () => {
    const supabase = supabaseMock();

    const grant = await grantAccountAccess(
      {
        email: "founder@example.com",
        grantKind: "PRODUCT_HUNT",
        createdBy: "keegan",
      },
      { supabase },
    );

    expect(grant.entitlementSource).toBe("MANUAL");
    expect(grant.premiumExpiresAt).toEqual(expect.any(String));
    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "account_entitlements",
        operation: "update",
        values: expect.objectContaining({
          account_tier: "FREE_PREMIUM",
          subscription_status: "FREE_PREMIUM",
          entitlement_source: "MANUAL",
        }),
      }),
    );
    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "account_grant_events",
        operation: "insert",
        values: expect.objectContaining({
          grant_kind: "PRODUCT_HUNT_1MONTH",
          ai_soft_cap_cents: 50,
          ai_hard_cap_cents: 200,
        }),
      }),
    );
  });

  it("creates a founder lifetime grant without an expiration", async () => {
    const supabase = supabaseMock();

    const grant = await grantAccountAccess(
      {
        userId,
        grantKind: "FOUNDER_LIFETIME",
      },
      { supabase },
    );

    expect(grant.entitlementSource).toBe("FOUNDER_OFFER");
    expect(grant.premiumExpiresAt).toBeNull();
    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "account_entitlements",
        operation: "update",
        values: expect.objectContaining({
          entitlement_source: "FOUNDER_OFFER",
          premium_expires_at: null,
          founder_offer_redeemed_at: expect.any(String),
        }),
      }),
    );
  });

  it("creates a friends discount grant without an expiration", async () => {
    const supabase = supabaseMock();

    const grant = await grantAccountAccess(
      {
        userId,
        grantKind: "FRIENDS_DISCOUNT",
      },
      { supabase },
    );

    expect(grant.entitlementSource).toBe("MANUAL");
    expect(grant.premiumExpiresAt).toBeNull();
    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "account_entitlements",
        operation: "update",
        values: expect.objectContaining({
          account_tier: "FREE_PREMIUM",
          premium_expires_at: null,
          active_promo_kind: "FRIENDS_DISCOUNT",
          active_promo_label: "Friends access",
        }),
      }),
    );
  });
});
