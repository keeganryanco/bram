import { z } from "zod";
import {
  BramAIConfigError,
  assertBramAIReady,
  getBramAIConfig,
  type BramAIConfig,
} from "./config";
import { createBramAIResponse } from "./client";
import { createPseudonymousUserId, sanitizeAIInputText } from "./privacy";
import { buildNoteParseRequest } from "./requests";
import { ParsedWorkoutSchema, type ParsedWorkout } from "./schemas";
import {
  AIUsagePolicyError,
  prepareAIUsagePolicy,
  recordAIUsageEvent,
} from "./usage-policy";

export const WorkoutInterpretationInputSchema = z.object({
  noteText: z.string().min(1).max(12_000),
  userId: z.string().min(1).max(160).optional(),
  workoutDate: z.string().max(80).optional(),
  timezone: z.string().max(80).optional(),
});

export type WorkoutInterpretationInput = z.infer<
  typeof WorkoutInterpretationInputSchema
>;

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

type WorkoutAIClients = {
  createResponse?: (
    request: ReturnType<typeof buildNoteParseRequest>,
  ) => Promise<BramAIResponseLike>;
  config?: BramAIConfig;
  supabase?: Parameters<typeof prepareAIUsagePolicy>[0]["supabase"];
};

export class WorkoutInterpretationError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.name = "WorkoutInterpretationError";
    this.status = status;
  }
}

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

export function parseWorkoutInterpretationResponse(
  response: BramAIResponseLike,
) {
  const text = outputText(response);
  if (!text) {
    throw new WorkoutInterpretationError("AI response did not include text.");
  }

  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new WorkoutInterpretationError("AI response was not valid JSON.");
  }

  return ParsedWorkoutSchema.parse(json);
}

export function verifyAIRouteToken(
  headers: Headers,
  env: Record<string, string | undefined> = process.env,
) {
  const expected = env.BRAM_AI_ROUTE_TOKEN;
  if (!expected) {
    throw new BramAIConfigError("BRAM_AI_ROUTE_TOKEN is missing.");
  }

  const authorization = headers.get("authorization");
  const bearer = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  const headerToken = headers.get("x-bram-ai-route-token");

  if (bearer !== expected && headerToken !== expected) {
    throw new WorkoutInterpretationError("Unauthorized.", 401);
  }
}

export async function interpretWorkoutNoteWithAI(
  input: WorkoutInterpretationInput,
  clients: WorkoutAIClients = {},
): Promise<{
  parsedWorkout: ParsedWorkout;
  redactions: ReturnType<typeof sanitizeAIInputText>["redactions"];
  responseId?: string;
  model?: string;
}> {
  const config = clients.config ?? getBramAIConfig();
  assertBramAIReady(config);

  const parsedInput = WorkoutInterpretationInputSchema.parse(input);
  const policy = await prepareAIUsagePolicy({
    userId: parsedInput.userId,
    task: "note_parse",
    config,
    supabase: clients.supabase,
  });
  const sanitized = sanitizeAIInputText(
    parsedInput.noteText,
    policy.config.maxNoteChars,
  );
  const pseudonymousUserId = parsedInput.userId
    ? createPseudonymousUserId(parsedInput.userId, policy.config.pseudonymSalt!)
    : undefined;
  const context = [
    parsedInput.workoutDate ? `Workout date: ${parsedInput.workoutDate}` : null,
    parsedInput.timezone ? `Timezone: ${parsedInput.timezone}` : null,
  ]
    .filter(Boolean)
    .join("\n");

  const request = buildNoteParseRequest({
    noteText: context
      ? `${context}\n\nWorkout note:\n${sanitized.text}`
      : sanitized.text,
    pseudonymousUserId,
    config: policy.config,
  });
  const response: BramAIResponseLike = clients.createResponse
    ? await clients.createResponse(request)
    : ((await createBramAIResponse(request)) as BramAIResponseLike);
  await recordAIUsageEvent({
    userId: policy.billableUserId,
    task: "note_parse",
    model: response.model ?? request.model,
    requestedModel: request.model,
    responseId: response.id,
    response,
    decision: policy.decision,
    config: policy.config,
    supabase: clients.supabase,
  });

  return {
    parsedWorkout: parseWorkoutInterpretationResponse(response),
    redactions: sanitized.redactions,
    responseId: response.id,
    model: response.model,
  };
}

export { AIUsagePolicyError };
