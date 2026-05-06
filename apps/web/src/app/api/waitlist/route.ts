import { NextResponse } from "next/server";
import {
  joinWaitlist,
  normalizeEmail,
  WaitlistConfigError,
} from "@/lib/waitlist";

const successResponse = {
  message: "You are on the list. We will send early access updates soon.",
};

export async function POST(request: Request) {
  let body: unknown;

  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { message: "Send a valid email address." },
      { status: 400 },
    );
  }

  const emailResult = normalizeEmail(
    typeof body === "object" && body !== null && "email" in body
      ? body.email
      : undefined,
  );

  if (!emailResult.success) {
    return NextResponse.json(
      { message: "Send a valid email address." },
      { status: 400 },
    );
  }

  try {
    await joinWaitlist({
      email: emailResult.data,
      source: "website",
      userAgent: request.headers.get("user-agent"),
      referrer: request.headers.get("referer"),
    });

    return NextResponse.json(successResponse);
  } catch (error) {
    if (error instanceof WaitlistConfigError) {
      return NextResponse.json(
        { message: "Waitlist is not configured yet." },
        { status: 503 },
      );
    }

    console.error("waitlist_signup_failed", error);
    return NextResponse.json(
      { message: "Could not join right now. Try again soon." },
      { status: 500 },
    );
  }
}
