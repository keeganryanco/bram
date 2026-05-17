import { NextResponse } from "next/server";
import {
  PromoRedemptionError,
  redeemPromoCodeForToken,
} from "@/lib/promo-redemption";

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
    return NextResponse.json({ message: "Send a promo code." }, { status: 400 });
  }

  const code =
    typeof body === "object" && body !== null && "code" in body
      ? String((body as { code: unknown }).code)
      : "";

  try {
    const account = await redeemPromoCodeForToken(token, code);
    return NextResponse.json(account);
  } catch (error) {
    if (error instanceof PromoRedemptionError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }

    console.error("promo_redemption_failed", error);
    return NextResponse.json(
      { message: "Could not redeem promo code." },
      { status: 500 },
    );
  }
}
