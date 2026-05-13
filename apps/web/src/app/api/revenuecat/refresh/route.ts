import { NextResponse } from "next/server";
import {
  refreshRevenueCatEntitlementForToken,
  RevenueCatConfigError,
} from "@/lib/revenuecat";

export async function POST(request: Request) {
  const authorization = request.headers.get("authorization");
  const token = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : null;

  if (!token) {
    return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
  }

  try {
    const account = await refreshRevenueCatEntitlementForToken(token);
    return NextResponse.json(account);
  } catch (error) {
    if (error instanceof RevenueCatConfigError) {
      return NextResponse.json(
        { message: "RevenueCat is not configured." },
        { status: 503 },
      );
    }

    console.error("revenuecat_refresh_failed", error);
    return NextResponse.json(
      { message: "Could not refresh subscription." },
      { status: 500 },
    );
  }
}
