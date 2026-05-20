import { NextResponse } from "next/server";
import { claimReferralCodeForToken, ReferralError } from "@/lib/referrals";

export async function POST(request: Request) {
  const authorization = request.headers.get("authorization");
  const token = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : null;

  if (!token) {
    return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ message: "Send a referral code." }, { status: 400 });
  }

  const code =
    typeof body === "object" && body !== null && "code" in body
      ? String((body as { code: unknown }).code)
      : "";

  try {
    const account = await claimReferralCodeForToken(token, code);
    return NextResponse.json(account);
  } catch (error) {
    if (error instanceof ReferralError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("claim_referral_failed", error);
    return NextResponse.json(
      { message: "Could not claim referral." },
      { status: 500 },
    );
  }
}
