import { NextResponse } from "next/server";
import {
  AccountDeletionConfigError,
  deleteAccountForToken,
} from "@/lib/account-deletion";

export async function POST(request: Request) {
  const authorization = request.headers.get("authorization");
  const token = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : null;

  if (!token) {
    return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
  }

  try {
    await deleteAccountForToken(token);
    return NextResponse.json({ message: "Account deleted." });
  } catch (error) {
    if (error instanceof AccountDeletionConfigError) {
      return NextResponse.json(
        { message: "Account deletion is not configured." },
        { status: 503 },
      );
    }

    if (error instanceof Error && error.message === "Invalid Supabase session.") {
      return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
    }

    console.error("account_deletion_failed", error);
    return NextResponse.json(
      { message: "Could not delete account." },
      { status: 500 },
    );
  }
}
