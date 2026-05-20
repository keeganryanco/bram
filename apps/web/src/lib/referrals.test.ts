import { describe, expect, it, vi } from "vitest";
import {
  claimReferralCodeForToken,
  referralProgramForToken,
} from "./referrals";
import { fetchAccountSnapshot } from "./revenuecat";

vi.mock("./revenuecat", () => ({
  fetchAccountSnapshot: vi.fn(async () => ({
    account_tier: "PREMIUM",
    entitlement_source: "APP_STORE",
    subscription_status: "ACTIVE",
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
      shareURL: "https://www.trybram.app/referral/BRAMABC12345",
    });
    expect(supabase.inserts).toHaveLength(0);
  });

  it("rejects self referral redemption", async () => {
    const supabase = makeReferralSupabase({ referralCodeOwner: referredUserId });

    await expect(
      claimReferralCodeForToken("token", "BRAMABC12345", {
        supabase: supabase.client,
      }),
    ).rejects.toMatchObject({
      status: 403,
    });
  });

  it("records attribution and queues an Apple offer reward for a valid code", async () => {
    const supabase = makeReferralSupabase();

    const result = await claimReferralCodeForToken("token", "BRAMABC12345", {
      supabase: supabase.client,
    });

    expect(result).toMatchObject({ account_tier: "PREMIUM" });
    expect(supabase.inserts).toContainEqual(
      expect.objectContaining({
        table: "account_referral_rewards",
        values: expect.objectContaining({
          user_id: referrerUserId,
          status: "QUEUED",
        }),
      }),
    );
  });

  it("requires Apple subscription access before referral attribution is claimed", async () => {
    vi.mocked(fetchAccountSnapshot).mockResolvedValueOnce({
      account_tier: "FREE",
      entitlement_source: "NONE",
      subscription_status: "NONE",
    });
    const supabase = makeReferralSupabase();

    await expect(
      claimReferralCodeForToken("token", "BRAMABC12345", {
        supabase: supabase.client,
      }),
    ).rejects.toMatchObject({
      status: 402,
    });
    expect(supabase.inserts).toHaveLength(0);
  });
});
