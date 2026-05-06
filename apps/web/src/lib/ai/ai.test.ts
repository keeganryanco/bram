import { describe, expect, it } from "vitest";
import {
  assertBramAIReady,
  buildInlineSuggestionRequest,
  buildNoteParseRequest,
  buildWeeklyReviewRequest,
  createPseudonymousUserId,
  getBramAIConfig,
  sanitizeAIInputText,
  selectModelForTask,
} from ".";

describe("getBramAIConfig", () => {
  it("defaults to disabled server-side AI with planned model tiers", () => {
    const config = getBramAIConfig({});

    expect(config.enabled).toBe(false);
    expect(config.models.fastModel).toBe("gpt-5.4-mini");
    expect(config.models.strongModel).toBe("gpt-5.4");
    expect(config.models.premiumModel).toBe("gpt-5.5");
    expect(config.monthlyActiveUserBudgetCents).toBe(40);
  });

  it("requires key and pseudonym salt before runtime use", () => {
    const config = getBramAIConfig({ BRAM_AI_ENABLED: "true" });

    expect(() => assertBramAIReady(config)).toThrow("OPENAI_API_KEY");
  });
});

describe("selectModelForTask", () => {
  const config = getBramAIConfig({
    BRAM_AI_FAST_MODEL: "fast",
    BRAM_AI_STRONG_MODEL: "strong",
    BRAM_AI_PREMIUM_MODEL: "premium",
  });

  it("routes cheap background tasks to the fast model", () => {
    expect(selectModelForTask("note_parse", config)).toBe("fast");
    expect(selectModelForTask("exercise_normalization", config)).toBe("fast");
    expect(selectModelForTask("inline_suggestion", config)).toBe("fast");
  });

  it("routes synthesis tasks to stronger models", () => {
    expect(selectModelForTask("weekly_review", config)).toBe("strong");
    expect(selectModelForTask("onboarding_profile", config)).toBe("strong");
    expect(selectModelForTask("complex_request", config)).toBe("premium");
  });
});

describe("AI privacy helpers", () => {
  it("redacts direct identifiers and truncates long notes", () => {
    const result = sanitizeAIInputText(
      "Email me at lifter@example.com or call 555-123-4567.\nBench 225x5.",
      60,
    );

    expect(result.text).toContain("[redacted-email]");
    expect(result.text).toContain("[redacted-phone]");
    expect(result.redactions.emails).toBe(1);
    expect(result.redactions.phoneNumbers).toBe(1);
    expect(result.redactions.truncated).toBe(true);
  });

  it("creates stable pseudonymous ids without exposing the original id", () => {
    const first = createPseudonymousUserId("user_123", "test-salt");
    const second = createPseudonymousUserId("user_123", "test-salt");

    expect(first).toBe(second);
    expect(first).toHaveLength(32);
    expect(first).not.toContain("user_123");
  });
});

describe("AI request builders", () => {
  it("builds structured note parsing requests", () => {
    const request = buildNoteParseRequest({
      noteText: "Bench 225 3x5, row 135 3x8",
      pseudonymousUserId: "abc",
    });

    expect(request.model).toBe("gpt-5.4-mini");
    expect(request.text?.format.type).toBe("json_schema");
    expect(request.metadata).toEqual({
      bram_task: "note_parse",
      pseudonymous_user_id: "abc",
    });
  });

  it("keeps suggestions and weekly reviews schema-bound", () => {
    expect(
      buildInlineSuggestionRequest({ structuredHistoryJson: "{}" }).text?.format
        .type,
    ).toBe("json_schema");
    expect(buildWeeklyReviewRequest({ weeklyDataJson: "{}" }).text?.format.type)
      .toBe("json_schema");
  });
});
