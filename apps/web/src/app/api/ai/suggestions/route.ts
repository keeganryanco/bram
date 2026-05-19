import { NextResponse } from "next/server";
import {
  BramAIConfigError,
  AIUsagePolicyError,
  generateWorkoutSuggestionsWithAI,
  supabaseAccessTokenFromRequest,
  userIdFromSuggestionAccessToken,
  verifyAIRouteToken,
  WorkoutInterpretationError,
  WorkoutSuggestionError,
  WorkoutSuggestionInputSchema,
} from "@/lib/ai";

export async function POST(request: Request) {
  try {
    verifyAIRouteToken(request.headers);
  } catch (error) {
    if (error instanceof WorkoutInterpretationError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    if (error instanceof BramAIConfigError) {
      return NextResponse.json(
        { message: "AI suggestions are not configured yet." },
        { status: 503 },
      );
    }

    throw error;
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { message: "Send valid suggestion context." },
      { status: 400 },
    );
  }

  const input = WorkoutSuggestionInputSchema.safeParse(body);
  if (!input.success) {
    return NextResponse.json(
      { message: "Send valid suggestion context." },
      { status: 400 },
    );
  }

  try {
    const userId = await userIdFromSuggestionAccessToken(
      supabaseAccessTokenFromRequest(request),
    );
    const result = await generateWorkoutSuggestionsWithAI({
      ...input.data,
      userId: userId ?? undefined,
    });
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof BramAIConfigError) {
      return NextResponse.json(
        { message: "AI suggestions are not configured yet." },
        { status: 503 },
      );
    }

    if (error instanceof WorkoutSuggestionError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    if (error instanceof AIUsagePolicyError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("ai_suggestions_failed", error);
    return NextResponse.json(
      { message: "Could not generate suggestions right now." },
      { status: 500 },
    );
  }
}
