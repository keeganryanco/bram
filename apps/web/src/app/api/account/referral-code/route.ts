import { NextResponse } from "next/server";
import { referralProgramForToken, ReferralError } from "@/lib/referrals";

export async function GET(request: Request) {
  const authorization = request.headers.get("authorization");
  const token = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : null;

  if (!token) {
    return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
  }

  try {
    const referral = await referralProgramForToken(token);
    return NextResponse.json(referral);
  } catch (error) {
    if (error instanceof ReferralError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("referral_code_failed", error);
    return NextResponse.json(
      { message: "Could not load referral code." },
      { status: 500 },
    );
  }
}
