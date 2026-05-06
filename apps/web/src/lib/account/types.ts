import { z } from "zod";

export const AccountTierSchema = z.enum(["FREE", "PREMIUM", "FREE_PREMIUM"]);
export const SubscriptionStatusSchema = z.enum([
  "NONE",
  "TRIAL",
  "ACTIVE",
  "GRACE_PERIOD",
  "EXPIRED",
  "CANCELED",
  "BILLING_RETRY",
  "FREE_PREMIUM",
]);
export const EntitlementSourceSchema = z.enum([
  "NONE",
  "APP_STORE",
  "REVENUECAT",
  "FOUNDER_OFFER",
  "MANUAL",
  "DEV",
]);

export const AccountSnapshotSchema = z.object({
  user_id: z.string().uuid(),
  email: z.string().email(),
  display_name: z.string().nullable(),
  preferred_units: z.enum(["lb", "kg"]),
  onboarding_completed_at: z.string().nullable(),
  account_tier: AccountTierSchema,
  subscription_status: SubscriptionStatusSchema,
  entitlement_source: EntitlementSourceSchema,
  is_developer: z.boolean(),
  founder_offer_eligible: z.boolean(),
  premium_expires_at: z.string().nullable(),
  entitlements_updated_at: z.string(),
});

export type AccountTier = z.infer<typeof AccountTierSchema>;
export type SubscriptionStatus = z.infer<typeof SubscriptionStatusSchema>;
export type EntitlementSource = z.infer<typeof EntitlementSourceSchema>;
export type AccountSnapshot = z.infer<typeof AccountSnapshotSchema>;

export function hasPremiumAccess(account: Pick<AccountSnapshot, "account_tier">) {
  return account.account_tier === "PREMIUM" || account.account_tier === "FREE_PREMIUM";
}

export function hasDeveloperAccess(
  account: Pick<AccountSnapshot, "is_developer">,
) {
  return account.is_developer;
}
