import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import {
  BramAIConfigError,
  getBramAIConfig,
  type BramAIConfig,
} from "./config";
import type { BramAITask } from "./requests";

const uuidSchema = z.string().uuid();

type QueryResult<T> = Promise<{ data: T; error: unknown | null }>;

type AIUsageSupabase = {
  from: (table: string) => {
    select: (columns?: string) => {
      eq: (column: string, value: string) => {
        single: () => QueryResult<unknown>;
        gte: (column: string, value: string) => QueryResult<unknown[]>;
      };
    };
    insert: (values: Record<string, unknown>) => Promise<{ error: unknown | null }>;
  };
};

type AIUsageResponse = {
  usage?: unknown;
};

export type AIUsagePolicyDecision = "NORMAL" | "DOWNGRADED" | "BLOCKED";

export class AIUsagePolicyError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.name = "AIUsagePolicyError";
    this.status = status;
  }
}

let supabaseAdmin: AIUsageSupabase | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new BramAIConfigError("Supabase AI usage environment is missing.");
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as AIUsageSupabase;
  return supabaseAdmin;
}

export function usageMonth(date = new Date()) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}-01`;
}

function centsFromUsage(
  response: AIUsageResponse,
  config: BramAIConfig,
) {
  const usage = response.usage;
  if (!usage || typeof usage !== "object") {
    return config.fallbackRequestCostCents;
  }

  const inputTokens =
    "input_tokens" in usage && typeof usage.input_tokens === "number"
      ? usage.input_tokens
      : 0;
  const outputTokens =
    "output_tokens" in usage && typeof usage.output_tokens === "number"
      ? usage.output_tokens
      : 0;
  const estimated = Math.ceil((inputTokens + outputTokens * 4) / 100_000);
  return Math.max(estimated, config.fallbackRequestCostCents);
}

function shouldBudgetAccount(account: {
  account_tier?: string;
  entitlement_source?: string;
  is_developer?: boolean;
}) {
  return (
    !account.is_developer &&
    account.account_tier === "FREE_PREMIUM" &&
    ["FOUNDER_OFFER", "MANUAL"].includes(account.entitlement_source ?? "")
  );
}

function downgradedConfig(config: BramAIConfig): BramAIConfig {
  return {
    ...config,
    models: {
      ...config.models,
      strongModel: config.models.fastModel,
      premiumModel: config.models.fastModel,
    },
  };
}

export async function prepareAIUsagePolicy(params: {
  userId?: string;
  task: BramAITask;
  config?: BramAIConfig;
  supabase?: AIUsageSupabase;
}) {
  const config = params.config ?? getBramAIConfig();
  if (!params.userId || !uuidSchema.safeParse(params.userId).success) {
    return {
      config,
      decision: "NORMAL" as AIUsagePolicyDecision,
      billableUserId: undefined,
      monthlyCostCents: 0,
    };
  }

  const supabase = params.supabase ?? getSupabaseAdmin();
  const { data: account, error: accountError } = await supabase
    .from("account_snapshot")
    .select("account_tier, entitlement_source, is_developer")
    .eq("user_id", params.userId)
    .single();

  if (accountError || !account || typeof account !== "object") {
    throw new AIUsagePolicyError("Could not load account budget policy.");
  }

  if (!shouldBudgetAccount(account)) {
    return {
      config,
      decision: "NORMAL" as AIUsagePolicyDecision,
      billableUserId: params.userId,
      monthlyCostCents: 0,
    };
  }

  const month = usageMonth();
  const { data: events, error: usageError } = await supabase
    .from("ai_usage_events")
    .select("estimated_cost_cents")
    .eq("user_id", params.userId)
    .gte("usage_month", month);

  if (usageError || !Array.isArray(events)) {
    throw new AIUsagePolicyError("Could not load account AI usage.");
  }

  const monthlyCostCents = events.reduce<number>((total, event) => {
    if (
      event &&
      typeof event === "object" &&
      "estimated_cost_cents" in event &&
      typeof event.estimated_cost_cents === "number"
    ) {
      return total + event.estimated_cost_cents;
    }
    return total;
  }, 0);

  if (monthlyCostCents >= config.promoFounderHardCapCents) {
    await recordAIUsageEvent({
      userId: params.userId,
      task: params.task,
      model: config.models.fastModel,
      requestedModel: config.models.premiumModel,
      estimatedCostCents: 0,
      decision: "BLOCKED",
      supabase,
    });
    throw new AIUsagePolicyError("AI usage limit reached for this month.", 429);
  }

  if (monthlyCostCents >= config.promoFounderSoftCapCents) {
    return {
      config: downgradedConfig(config),
      decision: "DOWNGRADED" as AIUsagePolicyDecision,
      billableUserId: params.userId,
      monthlyCostCents,
    };
  }

  return {
    config,
    decision: "NORMAL" as AIUsagePolicyDecision,
    billableUserId: params.userId,
    monthlyCostCents,
  };
}

export async function recordAIUsageEvent(params: {
  userId?: string;
  task: BramAITask;
  model?: string;
  requestedModel?: string;
  responseId?: string;
  response?: AIUsageResponse;
  estimatedCostCents?: number;
  decision?: AIUsagePolicyDecision;
  config?: BramAIConfig;
  supabase?: AIUsageSupabase;
}) {
  if (!params.userId || !uuidSchema.safeParse(params.userId).success) {
    return;
  }

  const config = params.config ?? getBramAIConfig();
  const supabase = params.supabase ?? getSupabaseAdmin();
  const estimatedCostCents =
    params.estimatedCostCents ??
    (params.response ? centsFromUsage(params.response, config) : config.fallbackRequestCostCents);
  const { error } = await supabase.from("ai_usage_events").insert({
    user_id: params.userId,
    usage_month: usageMonth(),
    task: params.task,
    model: params.model ?? "unknown",
    requested_model: params.requestedModel ?? null,
    estimated_cost_cents: estimatedCostCents,
    policy_decision: params.decision ?? "NORMAL",
    response_id: params.responseId ?? null,
  });

  if (error) {
    throw new AIUsagePolicyError("Could not record AI usage.");
  }
}
