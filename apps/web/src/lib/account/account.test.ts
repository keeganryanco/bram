import { describe, expect, it } from "vitest";
import {
  AccountSnapshotSchema,
  hasDeveloperAccess,
  hasPremiumAccess,
} from "./types";

describe("AccountSnapshotSchema", () => {
  it("accepts the app-facing account snapshot shape", () => {
    const parsed = AccountSnapshotSchema.parse({
      user_id: "11111111-1111-4111-8111-111111111111",
      email: "keegan@trybram.app",
      display_name: "Keegan",
      preferred_units: "lb",
      onboarding_completed_at: null,
      account_tier: "FREE_PREMIUM",
      subscription_status: "FREE_PREMIUM",
      entitlement_source: "MANUAL",
      is_developer: true,
      founder_offer_eligible: true,
      premium_expires_at: null,
      entitlements_updated_at: "2026-05-06T14:31:58Z",
    });

    expect(hasPremiumAccess(parsed)).toBe(true);
    expect(hasDeveloperAccess(parsed)).toBe(true);
  });

  it("treats free accounts as non-premium", () => {
    expect(hasPremiumAccess({ account_tier: "FREE" })).toBe(false);
  });
});
