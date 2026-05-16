import { NextResponse } from "next/server";
import {
  bearerTokenFromRequest,
  createSupportRequestForToken,
  SupportConfigError,
  SupportRequestError,
  SupportRequestInputSchema,
} from "@/lib/support";

export async function POST(request: Request) {
  const token = bearerTokenFromRequest(request);
  if (!token) {
    return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { message: "Send a valid support request." },
      { status: 400 },
    );
  }

  const input = SupportRequestInputSchema.safeParse(body);
  if (!input.success) {
    return NextResponse.json(
      { message: "Send a valid support request." },
      { status: 400 },
    );
  }

  try {
    const result = await createSupportRequestForToken(token, input.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof SupportConfigError) {
      return NextResponse.json(
        { message: "Support is not configured." },
        { status: 503 },
      );
    }

    if (error instanceof SupportRequestError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("support_request_failed", error);
    return NextResponse.json(
      { message: "Could not send support request." },
      { status: 500 },
    );
  }
}
