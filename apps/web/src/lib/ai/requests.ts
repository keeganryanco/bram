import { z } from "zod";
import {
  type BramAIConfig,
  getBramAIConfig,
} from "./config";
import {
  BRAM_AI_SYSTEM_PROMPT,
  COMPLEX_REQUEST_PROMPT,
  INLINE_SUGGESTION_PROMPT,
  NOTE_PARSER_PROMPT,
  ONBOARDING_PROFILE_PROMPT,
  WEEKLY_REVIEW_PROMPT,
  WORKOUT_SUGGESTION_PROMPT,
} from "./prompts";
import {
  InlineSuggestionSchema,
  OnboardingTrainingProfileSchema,
  ParsedWorkoutSchema,
  WeeklyReviewSchema,
  WorkoutSuggestionResponseSchema,
} from "./schemas";

export type BramAITask =
  | "note_parse"
  | "exercise_normalization"
  | "inline_suggestion"
  | "workout_suggestions"
  | "weekly_review"
  | "onboarding_profile"
  | "complex_request";

type BramAIResponseFormat =
  | { type: "text" }
  | {
      type: "json_schema";
      name: string;
      strict: true;
      schema: Record<string, unknown>;
    };

export type BramAIResponseRequest = {
  model: string;
  input: Array<{
    role: "system" | "user";
    content: Array<{ type: "input_text"; text: string }>;
  }>;
  text?: {
    format: BramAIResponseFormat;
  };
  max_output_tokens: number;
  metadata: {
    bram_task: BramAITask;
    pseudonymous_user_id?: string;
  };
};

function jsonSchema(name: string, schema: z.ZodType) {
  return {
    type: "json_schema" as const,
    name,
    strict: true as const,
    schema: z.toJSONSchema(schema) as Record<string, unknown>,
  };
}

export function selectModelForTask(
  task: BramAITask,
  config: BramAIConfig = getBramAIConfig(),
) {
  switch (task) {
    case "note_parse":
    case "exercise_normalization":
    case "inline_suggestion":
    case "workout_suggestions":
      return config.models.fastModel;
    case "weekly_review":
    case "onboarding_profile":
      return config.models.strongModel;
    case "complex_request":
      return config.models.premiumModel;
  }
}

function createInput(systemPrompt: string, userPrompt: string) {
  return [
    {
      role: "system" as const,
      content: [{ type: "input_text" as const, text: systemPrompt }],
    },
    {
      role: "user" as const,
      content: [{ type: "input_text" as const, text: userPrompt }],
    },
  ];
}

function baseRequest(params: {
  task: BramAITask;
  model: string;
  userPrompt: string;
  maxOutputTokens: number;
  pseudonymousUserId?: string;
  format?: BramAIResponseFormat;
}): BramAIResponseRequest {
  return {
    model: params.model,
    input: createInput(BRAM_AI_SYSTEM_PROMPT, params.userPrompt),
    text: params.format ? { format: params.format } : undefined,
    max_output_tokens: params.maxOutputTokens,
    metadata: {
      bram_task: params.task,
      pseudonymous_user_id: params.pseudonymousUserId,
    },
  };
}

export function buildNoteParseRequest(params: {
  noteText: string;
  pseudonymousUserId?: string;
  config?: BramAIConfig;
}) {
  const task: BramAITask = "note_parse";

  return baseRequest({
    task,
    model: selectModelForTask(task, params.config),
    userPrompt: `${NOTE_PARSER_PROMPT}\n\nWorkout note:\n${params.noteText}`,
    maxOutputTokens: 900,
    pseudonymousUserId: params.pseudonymousUserId,
    format: jsonSchema("bram_parsed_workout", ParsedWorkoutSchema),
  });
}

export function buildInlineSuggestionRequest(params: {
  structuredHistoryJson: string;
  pseudonymousUserId?: string;
  config?: BramAIConfig;
}) {
  const task: BramAITask = "inline_suggestion";

  return baseRequest({
    task,
    model: selectModelForTask(task, params.config),
    userPrompt: `${INLINE_SUGGESTION_PROMPT}\n\nStructured history:\n${params.structuredHistoryJson}`,
    maxOutputTokens: 180,
    pseudonymousUserId: params.pseudonymousUserId,
    format: jsonSchema("bram_inline_suggestion", InlineSuggestionSchema),
  });
}

export function buildWorkoutSuggestionsRequest(params: {
  structuredContextJson: string;
  pseudonymousUserId?: string;
  config?: BramAIConfig;
}) {
  const task: BramAITask = "workout_suggestions";

  return baseRequest({
    task,
    model: selectModelForTask(task, params.config),
    userPrompt: `${WORKOUT_SUGGESTION_PROMPT}\n\nStructured context:\n${params.structuredContextJson}`,
    maxOutputTokens: 520,
    pseudonymousUserId: params.pseudonymousUserId,
    format: jsonSchema("bram_workout_suggestions", WorkoutSuggestionResponseSchema),
  });
}

export function buildWeeklyReviewRequest(params: {
  weeklyDataJson: string;
  pseudonymousUserId?: string;
  config?: BramAIConfig;
}) {
  const task: BramAITask = "weekly_review";

  return baseRequest({
    task,
    model: selectModelForTask(task, params.config),
    userPrompt: `${WEEKLY_REVIEW_PROMPT}\n\nWeekly structured data:\n${params.weeklyDataJson}`,
    maxOutputTokens: 550,
    pseudonymousUserId: params.pseudonymousUserId,
    format: jsonSchema("bram_weekly_review", WeeklyReviewSchema),
  });
}

export function buildOnboardingProfileRequest(params: {
  onboardingAnswersJson: string;
  pseudonymousUserId?: string;
  config?: BramAIConfig;
}) {
  const task: BramAITask = "onboarding_profile";

  return baseRequest({
    task,
    model: selectModelForTask(task, params.config),
    userPrompt: `${ONBOARDING_PROFILE_PROMPT}\n\nOnboarding answers:\n${params.onboardingAnswersJson}`,
    maxOutputTokens: 450,
    pseudonymousUserId: params.pseudonymousUserId,
    format: jsonSchema(
      "bram_onboarding_training_profile",
      OnboardingTrainingProfileSchema,
    ),
  });
}

export function buildComplexRequest(params: {
  question: string;
  structuredHistoryJson: string;
  pseudonymousUserId?: string;
  config?: BramAIConfig;
}) {
  const task: BramAITask = "complex_request";

  return baseRequest({
    task,
    model: selectModelForTask(task, params.config),
    userPrompt: `${COMPLEX_REQUEST_PROMPT}\n\nQuestion:\n${params.question}\n\nStructured history:\n${params.structuredHistoryJson}`,
    maxOutputTokens: 420,
    pseudonymousUserId: params.pseudonymousUserId,
    format: { type: "text" },
  });
}
