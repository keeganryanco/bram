import { describe, expect, it, vi } from "vitest";
import { getBramAIConfig } from "./config";
import {
  AIUsagePolicyError,
  prepareAIUsagePolicy,
  recordAIUsageEvent,
} from "./usage-policy";

const userId = "11111111-1111-4111-8111-111111111111";

function supabaseMock(options: {
  accountTier?: string;
  entitlementSource?: string;
  isDeveloper?: boolean;
  usageCents?: number[];
} = {}) {
  const calls: { table: string; operation: string; values?: unknown }[] = [];

  return {
    calls,
    from: vi.fn((table: string) => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          single: vi.fn(async () => ({
            data: {
              account_tier: options.accountTier ?? "FREE_PREMIUM",
              entitlement_source: options.entitlementSource ?? "FOUNDER_OFFER",
              is_developer: options.isDeveloper ?? false,
            },
            error: null,
          })),
          gte: vi.fn(async () => ({
            data: (options.usageCents ?? []).map((estimated_cost_cents) => ({
              estimated_cost_cents,
            })),
            error: null,
          })),
        })),
      })),
      insert: vi.fn(async (values: Record<string, unknown>) => {
        calls.push({ table, operation: "insert", values });
        return { error: null };
      }),
    })),
  };
}

describe("AI usage policy", () => {
  const config = getBramAIConfig({
    BRAM_AI_ENABLED: "true",
    OPENAI_API_KEY: "test-key",
    BRAM_AI_PSEUDONYM_SALT: "test-salt",
    BRAM_AI_FAST_MODEL: "fast",
    BRAM_AI_STRONG_MODEL: "strong",
    BRAM_AI_PREMIUM_MODEL: "premium",
    BRAM_AI_PROMO_FOUNDER_SOFT_CAP_CENTS: "50",
    BRAM_AI_PROMO_FOUNDER_HARD_CAP_CENTS: "200",
  });

  it("uses normal models below the promo/founder soft cap", async () => {
    const policy = await prepareAIUsagePolicy({
      userId,
      task: "weekly_review",
      config,
      supabase: supabaseMock({ usageCents: [20, 10] }),
    });

    expect(policy.decision).toBe("NORMAL");
    expect(policy.config.models.strongModel).toBe("strong");
  });

  it("downgrades promo/founder users after fifty cents", async () => {
    const policy = await prepareAIUsagePolicy({
      userId,
      task: "weekly_review",
      config,
      supabase: supabaseMock({ usageCents: [50] }),
    });

    expect(policy.decision).toBe("DOWNGRADED");
    expect(policy.config.models.strongModel).toBe("fast");
    expect(policy.config.models.premiumModel).toBe("fast");
  });

  it("blocks promo/founder users after two dollars and records the block", async () => {
    const supabase = supabaseMock({ usageCents: [200] });

    await expect(
      prepareAIUsagePolicy({
        userId,
        task: "complex_request",
        config,
        supabase,
      }),
    ).rejects.toBeInstanceOf(AIUsagePolicyError);

    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "ai_usage_events",
        operation: "insert",
        values: expect.objectContaining({
          policy_decision: "BLOCKED",
          estimated_cost_cents: 0,
        }),
      }),
    );
  });

  it("records only AI usage metadata", async () => {
    const supabase = supabaseMock();

    await recordAIUsageEvent({
      userId,
      task: "note_parse",
      model: "fast",
      requestedModel: "fast",
      responseId: "resp_123",
      estimatedCostCents: 1,
      decision: "NORMAL",
      config,
      supabase,
    });

    expect(supabase.calls).toContainEqual(
      expect.objectContaining({
        table: "ai_usage_events",
        operation: "insert",
        values: expect.not.objectContaining({
          noteText: expect.any(String),
        }),
      }),
    );
  });
});
