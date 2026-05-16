import { NextResponse } from "next/server";
import {
  AppErrorReportInputSchema,
  bearerTokenFromRequest,
  recordAppErrorForToken,
  SupportConfigError,
  SupportRequestError,
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
      { message: "Send a valid error report." },
      { status: 400 },
    );
  }

  const input = AppErrorReportInputSchema.safeParse(body);
  if (!input.success) {
    return NextResponse.json(
      { message: "Send a valid error report." },
      { status: 400 },
    );
  }

  try {
    const result = await recordAppErrorForToken(token, input.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof SupportConfigError) {
      return NextResponse.json(
        { message: "Telemetry is not configured." },
        { status: 503 },
      );
    }

    if (error instanceof SupportRequestError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("app_error_report_failed", error);
    return NextResponse.json(
      { message: "Could not record error report." },
      { status: 500 },
    );
  }
}
