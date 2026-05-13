import { NextResponse } from "next/server";
import {
  normalizePasswordResetEmail,
  PasswordResetConfigError,
  sendPasswordResetEmail,
} from "@/lib/password-reset";

const passwordResetResponse = {
  message: "If that email has a Bram account, a reset link is on the way.",
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

  const emailResult = normalizePasswordResetEmail(
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
    await sendPasswordResetEmail(emailResult.data);
    return NextResponse.json(passwordResetResponse);
  } catch (error) {
    if (error instanceof PasswordResetConfigError) {
      return NextResponse.json(
        { message: "Password reset is not configured yet." },
        { status: 503 },
      );
    }

    console.error("password_reset_request_failed", error);
    return NextResponse.json(passwordResetResponse);
  }
}
