import { NextResponse } from "next/server";
import {
  AccountGrantError,
  AccountGrantRequestSchema,
  grantAccountAccess,
  verifyAdminGrantToken,
} from "@/lib/account-grants";

export async function POST(request: Request) {
  try {
    if (!verifyAdminGrantToken(request)) {
      return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
    }
  } catch (error) {
    if (error instanceof AccountGrantError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    throw error;
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { message: "Send a valid grant request." },
      { status: 400 },
    );
  }

  const input = AccountGrantRequestSchema.safeParse(body);
  if (!input.success) {
    return NextResponse.json(
      { message: "Send a valid grant request." },
      { status: 400 },
    );
  }

  try {
    const grant = await grantAccountAccess(input.data);
    return NextResponse.json(grant);
  } catch (error) {
    if (error instanceof AccountGrantError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("account_grant_failed", error);
    return NextResponse.json(
      { message: "Could not grant account access." },
      { status: 500 },
    );
  }
}
