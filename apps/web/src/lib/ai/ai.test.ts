import { describe, expect, it } from "vitest";
import {
  assertBramAIReady,
  buildInlineSuggestionRequest,
  buildNoteParseRequest,
  buildPrivacySafeSuggestionContext,
  buildWeeklyReviewRequest,
  buildWorkoutSuggestionsRequest,
  createPseudonymousUserId,
  getBramAIConfig,
  interpretWorkoutNoteWithAI,
  ParsedWorkoutSchema,
  parseWorkoutInterpretationResponse,
  recordSuggestionFeedback,
  sanitizeAIInputText,
  selectModelForTask,
  userIdFromSuggestionAccessToken,
  verifyAIRouteToken,
  WorkoutInterpretationInputSchema,
  WorkoutSuggestionInputSchema,
  WorkoutSuggestionResponseSchema,
} from ".";
import { WORKOUT_SUGGESTION_PROMPT } from "./prompts";

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

  it("builds workout suggestions from typed structured context", () => {
    const input = WorkoutSuggestionInputSchema.parse({
      installId: "install-test-123",
      currentWorkout: {
        sets: 12,
        prs: 1,
        cardioMinutes: 10,
        energyBucket: "moderate",
        sessionKind: "mixed",
        activeExerciseKey: "barbell_bench_press",
        activeExerciseSetCount: 2,
        activeExerciseEffort: "hard",
      },
      exerciseHistorySummaries: [
        {
          exerciseKey: "barbell_bench_press",
          displayName: "Barbell Bench Press",
          bestSet: "205 x 5",
          estimatedOneRepMax: 239,
          recentSessionCount: 4,
          recommendationEvidence: ["upward_trend"],
          target: "210 x 4-5",
        },
      ],
      cardioHistorySummaries: [
        {
          activityType: "Running",
          recentSessionCount: 2,
          averageDurationMinutes: 12,
          bestDistance: "1 mi",
          estimatedCalories: "120",
          recommendation: "Repeat 1 mi and make it smoother.",
        },
      ],
      dailyMetrics: { duration: "55", heartRate: "unknown" },
      muscleVolume: [{ muscleGroup: "Chest", sets: 10 }],
      goals: {
        primaryGoal: "stronger",
        weeklyTrainingDays: 4,
        sessionLengthMinutes: 60,
        trainingStyles: ["gym"],
        equipment: ["fullGym"],
      },
      noteHints: {
        readiness: "high",
        equipment: "gym",
        constraint: "none",
        cardioIntent: "cardio_logged",
        sessionKind: "mixed",
      },
      workoutPattern: {
        label: "Chest pattern",
        confidence: "high",
        workoutCount: 5,
        matchedMuscleGroup: "Chest",
        matchedExerciseKeys: ["barbell_bench_press"],
        evidence: ["pattern_high"],
      },
      feedbackSummary: {},
    });
    const context = buildPrivacySafeSuggestionContext(input);
    const request = buildWorkoutSuggestionsRequest({ structuredContextJson: context });

    expect(request.text?.format.type).toBe("json_schema");
    expect(context).toContain("barbell_bench_press");
    expect(context).toContain("activeExerciseEffort");
    expect(context).toContain("Chest pattern");
    expect(context).not.toContain("rawNote");
  });

  it("strips unsafe health/body fields from suggestion context", () => {
    const input = WorkoutSuggestionInputSchema.parse({
      installId: "install-test-123",
      currentWorkout: {
        sets: 0,
        prs: 0,
        cardioMinutes: 0,
        energyBucket: "unknown",
        sessionKind: "unknown",
      },
      exerciseHistorySummaries: [],
      cardioHistorySummaries: [],
      dailyMetrics: { duration: "unknown", heartRate: "unknown" },
      muscleVolume: [],
      goals: {
        primaryGoal: "stronger",
        weeklyTrainingDays: 4,
        sessionLengthMinutes: 60,
        trainingStyles: [],
        equipment: [],
      },
      noteHints: {
        readiness: "unknown",
        equipment: "unknown",
        constraint: "none",
        cardioIntent: "none",
        sessionKind: "unknown",
      },
      feedbackSummary: {},
    });

    const context = buildPrivacySafeSuggestionContext({
      ...input,
      bodyweight: 192,
      rawNote: "Bench 225 x 5",
    } as never);

    expect(context).not.toContain("192");
    expect(context).not.toContain("Bench 225");
  });

  it("accepts richer suggestion responses while keeping visible text short", () => {
    const parsed = WorkoutSuggestionResponseSchema.parse({
      dailySuggestion: {
        type: "progression",
        category: "progression",
        text: "Barbell Bench Press: add one clean rep before increasing load.",
        evidence: ["upward_trend"],
        affectedExerciseKey: "barbell_bench_press",
      },
      exerciseSuggestions: [
        {
          exerciseKey: "barbell_bench_press",
          title: "Progression",
          text: "Repeat 205 and aim for 6 clean reps.",
          target: "205 x 6",
          evidence: ["saved_history"],
          reasonTags: ["double_progression"],
        },
      ],
      draft: null,
    });

    expect(parsed.dailySuggestion?.affectedExerciseKey).toBe("barbell_bench_press");
    expect(parsed.exerciseSuggestions[0]?.reasonTags).toContain("double_progression");
  });

  it("tells workout suggestions to avoid generic high-volume advice", () => {
    expect(WORKOUT_SUGGESTION_PROMPT).toContain("actual training history");
    expect(WORKOUT_SUGGESTION_PROMPT).toContain("Do not say volume is high unless");
    expect(WORKOUT_SUGGESTION_PROMPT).toContain("activeExerciseKey");
    expect(WORKOUT_SUGGESTION_PROMPT).toContain("workoutPattern");
    expect(WORKOUT_SUGGESTION_PROMPT).toContain("default draft should be null");
  });

  it("records suggestion feedback with verified user attribution", async () => {
    const inserts: unknown[] = [];
    await recordSuggestionFeedback(
      {
        installId: "install-test-123",
        suggestionId: "00000000-0000-4000-8000-000000000001",
        suggestionType: "daily",
        action: "thumbsDown",
        source: "ai",
        coarseContext: {
          evidence: "active_exercise",
          rawNote: "Bench 225 x 5",
        },
      },
      {
        userId: "00000000-0000-4000-8000-000000000002",
        supabase: {
          from: () => ({
            insert: (row: unknown) => {
              inserts.push(row);
              return { error: null };
            },
          }),
          auth: {
            getUser: async () => ({ data: { user: null }, error: null }),
          },
        } as never,
      },
    );

    expect(inserts[0]).toMatchObject({
      user_id: "00000000-0000-4000-8000-000000000002",
      suggestion_type: "daily",
    });
    expect(JSON.stringify(inserts[0])).not.toContain("Bench 225");
  });

  it("resolves suggestion user id from Supabase access token", async () => {
    const userId = await userIdFromSuggestionAccessToken("access-token", {
      supabase: {
        auth: {
          getUser: async (token: string) => ({
            data: { user: { id: token === "access-token" ? "user-123" : null } },
            error: null,
          }),
        },
      } as never,
    });

    expect(userId).toBe("user-123");
  });
});

describe("AI workout interpretation", () => {
  const parsedWorkoutJson = {
    workoutDate: null,
    title: "Leg Day",
    summary: "Leg session with squats and bodyweight accessories.",
    lines: [
      {
        lineIndex: 1,
        kind: "strength",
        segments: [
          {
            type: "exercise_anchor",
            text: "Reverse Nordic",
            exerciseKey: "reverse_nordic",
          },
        ],
      },
    ],
    exercises: [
      {
        name: "Reverse Nordic",
        normalizedName: "Reverse Nordic",
        exerciseKey: "reverse_nordic",
        muscleGroupHint: "Legs",
        sets: [
          {
            reps: 4,
            load: null,
            unit: "bodyweight",
            rpe: null,
            rir: null,
            note: null,
          },
        ],
        uncertainty: null,
      },
    ],
    sessionNotes: [],
    unresolvedText: [],
  };

  it("requires the temporary AI route token", () => {
    expect(() =>
      verifyAIRouteToken(new Headers(), { BRAM_AI_ROUTE_TOKEN: "secret" }),
    ).toThrow("Unauthorized");

    expect(() =>
      verifyAIRouteToken(new Headers({ authorization: "Bearer secret" }), {
        BRAM_AI_ROUTE_TOKEN: "secret",
      }),
    ).not.toThrow();
  });

  it("parses schema-bound model output", () => {
    const parsed = parseWorkoutInterpretationResponse({
      output_text: JSON.stringify(parsedWorkoutJson),
    });

    expect(parsed.exercises[0]?.exerciseKey).toBe("reverse_nordic");
  });

  it("accepts cardio entries and same-day workout sessions", () => {
    const parsed = ParsedWorkoutSchema.parse({
      ...parsedWorkoutJson,
      sessions: [
        {
          sessionIndex: 1,
          title: "Morning run",
          kind: "cardio",
          startLineIndex: 0,
          endLineIndex: 1,
        },
        {
          sessionIndex: 2,
          title: "Evening lift",
          kind: "strength",
          startLineIndex: 3,
          endLineIndex: null,
        },
      ],
      cardioEntries: [
        {
          activityType: "Running",
          durationMinutes: 10,
          distanceValue: 1,
          distanceUnit: "mi",
          paceText: null,
          sessionIndex: 1,
          sourceLineIndex: 1,
        },
      ],
    });

    expect(parsed.sessions[0]?.title).toBe("Morning run");
    expect(parsed.cardioEntries[0]?.distanceValue).toBe(1);
  });

  it("accepts repair mode with bounded target lines", () => {
    const parsed = WorkoutInterpretationInputSchema.parse({
      noteText: "Weighed 192.5 lbs\nLeg curls 70 for 8",
      mode: "repair",
      targetLines: [{ lineIndex: 1, text: "Leg curls 70 for 8" }],
      localSummary: {
        interpretedLineIndexes: [0],
        lowConfidenceLineIndexes: [],
        totalSets: 0,
        cardioMinutes: 0,
        unresolvedLineCount: 1,
      },
    });

    expect(parsed.mode).toBe("repair");
    expect(parsed.targetLines[0]?.lineIndex).toBe(1);
  });

  it("accepts timed strength sets in parser schema", () => {
    const parsed = ParsedWorkoutSchema.parse({
      ...parsedWorkoutJson,
      lines: [
        {
          lineIndex: 0,
          kind: "strength",
          segments: [
            { type: "exercise_anchor", text: "planks", exerciseKey: "planks" },
            { type: "metric", text: "3 x 75 sec", exerciseKey: null },
          ],
        },
      ],
      exercises: [
        {
          name: "planks",
          normalizedName: "Planks",
          exerciseKey: "planks",
          muscleGroupHint: "Abs",
          sets: Array.from({ length: 3 }, () => ({
            reps: null,
            load: null,
            durationSeconds: 75,
            unit: "bodyweight",
            rpe: null,
            rir: null,
            note: null,
          })),
          uncertainty: null,
        },
      ],
    });

    expect(parsed.exercises[0]?.sets[0]?.durationSeconds).toBe(75);
  });

  it("accepts structured exercise identity hints", () => {
    const parsed = ParsedWorkoutSchema.parse({
      ...parsedWorkoutJson,
      exercises: [
        {
          name: "chest press barbell",
          normalizedName: "Barbell Bench Press",
          exerciseKey: "barbell_bench_press",
          identity: {
            movementFamily: "chest_press",
            angle: "flat",
            equipment: "barbell",
            confidence: 0.92,
          },
          muscleGroupHint: "Chest",
          sets: [
            {
              reps: 8,
              load: 185,
              durationSeconds: null,
              unit: "lb",
              rpe: null,
              rir: null,
              note: null,
            },
          ],
          uncertainty: null,
        },
      ],
    });

    expect(parsed.exercises[0]?.identity?.equipment).toBe("barbell");
    expect(parsed.exercises[0]?.exerciseKey).toBe("barbell_bench_press");
  });

  it("rejects oversized repair target batches", () => {
    const input = {
      noteText: "Leg curls 70 for 8",
      mode: "repair",
      targetLines: Array.from({ length: 13 }, (_, index) => ({
        lineIndex: index,
        text: "Leg curls 70 for 8",
      })),
    };

    expect(() => WorkoutInterpretationInputSchema.parse(input)).toThrow();
  });

  it("sanitizes note text before sending to OpenAI", async () => {
    const calls: unknown[] = [];
    const result = await interpretWorkoutNoteWithAI(
      {
        noteText:
          "Email lifter@example.com\nReverse Nordic\n1 - 4\n2 - 5",
        mode: "audit",
        targetLines: [],
        userId: "user_123",
      },
      {
        config: getBramAIConfig({
          BRAM_AI_ENABLED: "true",
          OPENAI_API_KEY: "test-key",
          BRAM_AI_PSEUDONYM_SALT: "test-salt",
        }),
        createResponse: async (request) => {
          calls.push(request);
          return { id: "resp_1", model: request.model, output_text: JSON.stringify(parsedWorkoutJson) };
        },
      },
    );

    expect(result.parsedWorkout.exercises[0]?.name).toBe("Reverse Nordic");
    expect(result.redactions.emails).toBe(1);
    expect(JSON.stringify(calls[0])).toContain("[redacted-email]");
    expect(JSON.stringify(calls[0])).not.toContain("lifter@example.com");
    expect(JSON.stringify(calls[0])).not.toContain("user_123");
  });

  it("sends only repair target text during live repair", async () => {
    const calls: unknown[] = [];
    await interpretWorkoutNoteWithAI(
      {
        noteText: "Email lifter@example.com\nBench 185 3x8\nLeg curls 70 for 8",
        mode: "repair",
        targetLines: [{ lineIndex: 2, text: "Leg curls 70 for 8" }],
        userId: "user_123",
      },
      {
        config: getBramAIConfig({
          BRAM_AI_ENABLED: "true",
          OPENAI_API_KEY: "test-key",
          BRAM_AI_PSEUDONYM_SALT: "test-salt",
        }),
        createResponse: async (request) => {
          calls.push(request);
          return { id: "resp_1", model: request.model, output_text: JSON.stringify(parsedWorkoutJson) };
        },
      },
    );

    const payload = JSON.stringify(calls[0]);
    expect(payload).toContain("Repair mode");
    expect(payload).toContain("2: Leg curls 70 for 8");
    expect(payload).not.toContain("Bench 185");
    expect(payload).not.toContain("lifter@example.com");
  });

  it("preserves timed repair target line indexes", async () => {
    const calls: unknown[] = [];
    await interpretWorkoutNoteWithAI(
      {
        noteText: "Bench 185 3x8\nI did 75 sec planks x3",
        mode: "repair",
        targetLines: [{ lineIndex: 1, text: "I did 75 sec planks x3" }],
        userId: "user_123",
      },
      {
        config: getBramAIConfig({
          BRAM_AI_ENABLED: "true",
          OPENAI_API_KEY: "test-key",
          BRAM_AI_PSEUDONYM_SALT: "test-salt",
        }),
        createResponse: async (request) => {
          calls.push(request);
          return {
            id: "resp_1",
            model: request.model,
            output_text: JSON.stringify({
              ...parsedWorkoutJson,
              lines: [
                {
                  lineIndex: 1,
                  kind: "strength",
                  segments: [
                    { type: "exercise_anchor", text: "planks", exerciseKey: "planks" },
                    { type: "metric", text: "3 x 75 sec", exerciseKey: null },
                  ],
                },
              ],
              exercises: [
                {
                  name: "planks",
                  normalizedName: "Planks",
                  exerciseKey: "planks",
                  muscleGroupHint: "Abs",
                  sets: Array.from({ length: 3 }, () => ({
                    reps: null,
                    load: null,
                    durationSeconds: 75,
                    unit: "bodyweight",
                    rpe: null,
                    rir: null,
                    note: null,
                  })),
                  uncertainty: null,
                },
              ],
            }),
          };
        },
      },
    );

    const payload = JSON.stringify(calls[0]);
    expect(payload).toContain("1: I did 75 sec planks x3");
    expect(payload).not.toContain("Bench 185");
  });
});
