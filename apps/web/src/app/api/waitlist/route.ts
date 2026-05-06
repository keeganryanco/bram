import { NextResponse } from "next/server";
import {
  joinWaitlist,
  normalizeEmail,
  WaitlistConfigError,
} from "@/lib/waitlist";

const createdResponse = {
  message: "You are on the list. Check your email for a note from Keegan.",
};

const duplicateResponse = {
  message: "That email is already on the waitlist.",
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
    const result = await joinWaitlist({
      email: emailResult.data,
      source: "website",
      userAgent: request.headers.get("user-agent"),
      referrer: request.headers.get("referer"),
    });

    return NextResponse.json(
      result.status === "duplicate" ? duplicateResponse : createdResponse,
    );
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
