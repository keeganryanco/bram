import { NextResponse } from "next/server";
import {
  BramAIConfigError,
  recordSuggestionFeedback,
  SuggestionFeedbackInputSchema,
  verifyAIRouteToken,
  WorkoutInterpretationError,
  WorkoutSuggestionError,
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
        { message: "Suggestion feedback is not configured yet." },
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
      { message: "Send valid suggestion feedback." },
      { status: 400 },
    );
  }

  const input = SuggestionFeedbackInputSchema.safeParse(body);
  if (!input.success) {
    return NextResponse.json(
      { message: "Send valid suggestion feedback." },
      { status: 400 },
    );
  }

  try {
    const result = await recordSuggestionFeedback(input.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof BramAIConfigError) {
      return NextResponse.json(
        { message: "Suggestion feedback is not configured yet." },
        { status: 503 },
      );
    }

    if (error instanceof WorkoutSuggestionError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("suggestion_feedback_failed", error);
    return NextResponse.json(
      { message: "Could not record suggestion feedback right now." },
      { status: 500 },
    );
  }
}
