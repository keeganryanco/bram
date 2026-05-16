import { NextResponse } from "next/server";
import {
  BramAIConfigError,
  AIUsagePolicyError,
  interpretWorkoutNoteWithAI,
  verifyAIRouteToken,
  WorkoutInterpretationError,
  WorkoutInterpretationInputSchema,
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
        { message: "AI interpretation is not configured yet." },
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
      { message: "Send a valid workout note." },
      { status: 400 },
    );
  }

  const input = WorkoutInterpretationInputSchema.safeParse(body);
  if (!input.success) {
    return NextResponse.json(
      { message: "Send a valid workout note." },
      { status: 400 },
    );
  }

  try {
    const result = await interpretWorkoutNoteWithAI(input.data);
    return NextResponse.json({
      parsedWorkout: result.parsedWorkout,
      redactions: result.redactions,
      responseId: result.responseId,
      model: result.model,
    });
  } catch (error) {
    if (error instanceof BramAIConfigError) {
      return NextResponse.json(
        { message: "AI interpretation is not configured yet." },
        { status: 503 },
      );
    }

    if (error instanceof WorkoutInterpretationError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    if (error instanceof AIUsagePolicyError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("ai_workout_interpretation_failed", error);
    return NextResponse.json(
      { message: "Could not interpret this workout right now." },
      { status: 500 },
    );
  }
}
