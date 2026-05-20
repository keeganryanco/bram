import { describe, expect, it, vi } from "vitest";
import {
  redeemReferralCodeForToken,
  referralProgramForToken,
} from "./referrals";
import { grantAccountAccess } from "./account-grants";

vi.mock("./account-grants", () => ({
  grantAccountAccess: vi.fn(async () => undefined),
}));

vi.mock("./revenuecat", () => ({
  fetchAccountSnapshot: vi.fn(async () => ({
    account_tier: "FREE_PREMIUM",
    active_promo_kind: "REFERRAL_1MONTH",
  })),
}));

const referredUserId = "11111111-1111-4111-8111-111111111111";
const referrerUserId = "22222222-2222-4222-8222-222222222222";

function makeReferralSupabase(options: {
  userId?: string;
  existingCode?: string | null;
  referralCodeOwner?: string | null;
  redemptionInsertError?: { code?: string; message?: string } | null;
} = {}) {
  const state = {
    userId: options.userId ?? referredUserId,
    existingCode: options.existingCode ?? null,
    referralCodeOwner: options.referralCodeOwner ?? referrerUserId,
    redemptionInsertError: options.redemptionInsertError ?? null,
  };
  const inserts: { table: string; values: Record<string, unknown> }[] = [];

  function filter(table: string) {
    const filters: Record<string, string> = {};
    const api = {
      eq: vi.fn((column: string, value: string) => {
        filters[column] = value;
        return api;
      }),
      limit: vi.fn(async () => {
        if (table === "account_referral_redemptions") {
          return { data: [{ id: "redemption_1" }], error: null };
        }
        return { data: [], error: null };
      }),
      maybeSingle: vi.fn(async () => {
        if (table === "account_referral_codes" && state.existingCode) {
          return { data: { code: state.existingCode }, error: null };
        }
        return { data: null, error: null };
      }),
      single: vi.fn(async () => {
        if (table === "account_referral_codes" && state.referralCodeOwner) {
          return {
            data: { user_id: state.referralCodeOwner, code: filters.code },
            error: null,
          };
        }
        if (table === "account_referral_redemptions") {
          return { data: { id: "redemption_1" }, error: null };
        }
        if (table === "account_entitlements") {
          return {
            data: {
              account_tier: "FREE",
              entitlement_source: "MANUAL",
              is_developer: false,
              active_promo_kind: null,
              premium_expires_at: null,
            },
            error: null,
          };
        }
        return { data: null, error: null };
      }),
    };
    return api;
  }

  return {
    client: {
      auth: {
        getUser: vi.fn(async () => ({
          data: { user: { id: state.userId } },
          error: null,
        })),
      },
      from: vi.fn((table: string) => ({
        select: vi.fn(() => filter(table)),
        insert: vi.fn(async (values: Record<string, unknown>) => {
          inserts.push({ table, values });
          if (table === "account_referral_redemptions" && state.redemptionInsertError) {
            return { error: state.redemptionInsertError };
          }
          return { error: null };
        }),
      })),
    },
    inserts,
  };
}

describe("referrals", () => {
  it("returns an existing authenticated user's referral code", async () => {
    const supabase = makeReferralSupabase({ existingCode: "BRAMABC12345" });

    const result = await referralProgramForToken("token", {
      supabase: supabase.client,
    });

    expect(result).toMatchObject({
      code: "BRAMABC12345",
      successfulRedemptions: 1,
    });
    expect(supabase.inserts).toHaveLength(0);
  });

  it("rejects self referral redemption", async () => {
    const supabase = makeReferralSupabase({ referralCodeOwner: referredUserId });

    await expect(
      redeemReferralCodeForToken("token", "BRAMABC12345", {
        supabase: supabase.client,
      }),
    ).rejects.toMatchObject({
      status: 403,
    });
  });

  it("grants the friend and applies a referrer reward for a valid code", async () => {
    const supabase = makeReferralSupabase();

    const result = await redeemReferralCodeForToken("token", "BRAMABC12345", {
      supabase: supabase.client,
    });

    expect(result).toMatchObject({ active_promo_kind: "REFERRAL_1MONTH" });
    expect(grantAccountAccess).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: referredUserId,
        grantKind: "REFERRAL_1MONTH",
      }),
      expect.anything(),
    );
    expect(grantAccountAccess).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: referrerUserId,
        grantKind: "REFERRAL_1MONTH",
      }),
      expect.anything(),
    );
    expect(supabase.inserts).toContainEqual(
      expect.objectContaining({
        table: "account_referral_rewards",
        values: expect.objectContaining({
          user_id: referrerUserId,
          status: "APPLIED",
        }),
      }),
    );
  });
});
