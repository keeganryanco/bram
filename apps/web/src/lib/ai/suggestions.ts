import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  BramAIConfigError,
  assertBramAIReady,
  getBramAIConfig,
  type BramAIConfig,
} from "./config";
import { createBramAIResponse } from "./client";
import { createPseudonymousUserId } from "./privacy";
import { buildWorkoutSuggestionsRequest } from "./requests";
import {
  prepareAIUsagePolicy,
  recordAIUsageEvent,
} from "./usage-policy";
import {
  SuggestionFeedbackInputSchema,
  WorkoutSuggestionInputSchema,
  WorkoutSuggestionResponseSchema,
  type SuggestionFeedbackInput,
  type WorkoutSuggestionInput,
  type WorkoutSuggestionResponse,
} from "./schemas";

type BramAIResponseLike = {
  id?: string;
  model?: string;
  output_text?: string;
  output?: Array<{
    type?: string;
    content?: Array<{
      type?: string;
      text?: string;
    }>;
  }>;
  usage?: unknown;
};

type SuggestionAIClients = {
  createResponse?: (
    request: ReturnType<typeof buildWorkoutSuggestionsRequest>,
  ) => Promise<BramAIResponseLike>;
  config?: BramAIConfig;
  supabase?: Parameters<typeof prepareAIUsagePolicy>[0]["supabase"];
};

export class WorkoutSuggestionError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.name = "WorkoutSuggestionError";
    this.status = status;
  }
}

const unsafeKeys = new Set([
  "note",
  "noteText",
  "rawNote",
  "rawText",
  "body",
  "freeform",
  "injury",
  "healthNote",
  "bodyweight",
  "weight",
]);

function outputText(response: BramAIResponseLike) {
  if (response.output_text) {
    return response.output_text;
  }

  for (const item of response.output ?? []) {
    for (const content of item.content ?? []) {
      if (content.type === "output_text" && content.text) {
        return content.text;
      }
    }
  }

  return null;
}

function stripUnsafeFields(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(stripUnsafeFields);
  }

  if (!value || typeof value !== "object") {
    return value;
  }

  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => !unsafeKeys.has(key))
      .map(([key, child]) => [key, stripUnsafeFields(child)]),
  );
}

export function buildPrivacySafeSuggestionContext(
  input: WorkoutSuggestionInput,
) {
  const clean = stripUnsafeFields(input);
  const json = JSON.stringify(clean);
  if (json.length > 24_000) {
    throw new WorkoutSuggestionError("Suggestion context is too large.", 400);
  }
  return json;
}

export function parseWorkoutSuggestionResponse(response: BramAIResponseLike) {
  const text = outputText(response);
  if (!text) {
    throw new WorkoutSuggestionError("AI response did not include text.");
  }

  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new WorkoutSuggestionError("AI response was not valid JSON.");
  }

  return WorkoutSuggestionResponseSchema.parse(json);
}

export async function generateWorkoutSuggestionsWithAI(
  input: WorkoutSuggestionInput,
  clients: SuggestionAIClients = {},
): Promise<{
  suggestions: WorkoutSuggestionResponse;
  responseId?: string;
  model?: string;
}> {
  const config = clients.config ?? getBramAIConfig();
  assertBramAIReady(config);

  const parsedInput = WorkoutSuggestionInputSchema.parse(input);
  const policy = await prepareAIUsagePolicy({
    userId: parsedInput.userId,
    task: "workout_suggestions",
    config,
    supabase: clients.supabase,
  });
  const pseudonymousUserId = createPseudonymousUserId(
    parsedInput.userId ?? parsedInput.installId,
    policy.config.pseudonymSalt!,
  );
  const request = buildWorkoutSuggestionsRequest({
    structuredContextJson: buildPrivacySafeSuggestionContext(parsedInput),
    pseudonymousUserId,
    config: policy.config,
  });
  const response = clients.createResponse
    ? await clients.createResponse(request)
    : ((await createBramAIResponse(request)) as BramAIResponseLike);
  await recordAIUsageEvent({
    userId: policy.billableUserId,
    task: "workout_suggestions",
    model: response.model ?? request.model,
    requestedModel: request.model,
    responseId: response.id,
    response,
    decision: policy.decision,
    config: policy.config,
    supabase: clients.supabase,
  });

  return {
    suggestions: parseWorkoutSuggestionResponse(response),
    responseId: response.id,
    model: response.model,
  };
}

type SuggestionFeedbackClients = {
  supabase?: Pick<SupabaseClient, "from">;
};

let supabaseAdmin: SupabaseClient | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new BramAIConfigError("Supabase feedback environment is missing.");
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  return supabaseAdmin;
}

export async function recordSuggestionFeedback(
  input: SuggestionFeedbackInput,
  clients: SuggestionFeedbackClients = {},
) {
  const parsed = SuggestionFeedbackInputSchema.parse(input);
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const coarseContext = Object.fromEntries(
    Object.entries(parsed.coarseContext).filter(
      ([key]) => !unsafeKeys.has(key) && typeof key === "string",
    ),
  );

  const { error } = await supabase.from("suggestion_feedback").insert({
    install_id: parsed.installId,
    suggestion_id: parsed.suggestionId,
    suggestion_type: parsed.suggestionType,
    action: parsed.action,
    source: parsed.source,
    coarse_context: coarseContext,
  });

  if (error) {
    throw new WorkoutSuggestionError("Could not record suggestion feedback.");
  }

  return { status: "recorded" as const };
}
