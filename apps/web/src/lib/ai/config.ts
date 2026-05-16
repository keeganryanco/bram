export type BramAIModelConfig = {
  fastModel: string;
  strongModel: string;
  premiumModel: string;
};

export type BramAIConfig = {
  enabled: boolean;
  apiKey?: string;
  pseudonymSalt?: string;
  models: BramAIModelConfig;
  maxNoteChars: number;
  requestTimeoutMs: number;
  dailyUserRequestLimit: number;
  monthlyActiveUserBudgetCents: number;
  promoFounderSoftCapCents: number;
  promoFounderHardCapCents: number;
  fallbackRequestCostCents: number;
};

export class BramAIConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "BramAIConfigError";
  }
}

function readBoolean(value: string | undefined, fallback: boolean) {
  if (value === undefined) {
    return fallback;
  }

  return value === "true" || value === "1";
}

function readNumber(value: string | undefined, fallback: number) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function getBramAIConfig(
  env: Record<string, string | undefined> = process.env,
): BramAIConfig {
  return {
    enabled: readBoolean(env.BRAM_AI_ENABLED, false),
    apiKey: env.OPENAI_API_KEY,
    pseudonymSalt: env.BRAM_AI_PSEUDONYM_SALT,
    models: {
      fastModel: env.BRAM_AI_FAST_MODEL ?? "gpt-5.4-mini",
      strongModel: env.BRAM_AI_STRONG_MODEL ?? "gpt-5.4",
      premiumModel: env.BRAM_AI_PREMIUM_MODEL ?? "gpt-5.5",
    },
    maxNoteChars: readNumber(env.BRAM_AI_MAX_NOTE_CHARS, 6000),
    requestTimeoutMs: readNumber(env.BRAM_AI_REQUEST_TIMEOUT_MS, 15000),
    dailyUserRequestLimit: readNumber(env.BRAM_AI_DAILY_USER_REQUEST_LIMIT, 48),
    monthlyActiveUserBudgetCents: readNumber(
      env.BRAM_AI_MONTHLY_ACTIVE_USER_BUDGET_CENTS,
      40,
    ),
    promoFounderSoftCapCents: readNumber(
      env.BRAM_AI_PROMO_FOUNDER_SOFT_CAP_CENTS,
      50,
    ),
    promoFounderHardCapCents: readNumber(
      env.BRAM_AI_PROMO_FOUNDER_HARD_CAP_CENTS,
      200,
    ),
    fallbackRequestCostCents: readNumber(env.BRAM_AI_FALLBACK_REQUEST_COST_CENTS, 1),
  };
}

export function assertBramAIReady(config = getBramAIConfig()) {
  if (!config.enabled) {
    throw new BramAIConfigError("Bram AI is disabled.");
  }

  if (!config.apiKey) {
    throw new BramAIConfigError("OPENAI_API_KEY is missing.");
  }

  if (!config.pseudonymSalt) {
    throw new BramAIConfigError("BRAM_AI_PSEUDONYM_SALT is missing.");
  }
}
