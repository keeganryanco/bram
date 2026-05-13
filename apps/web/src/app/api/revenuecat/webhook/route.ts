import { NextResponse } from "next/server";
import {
  handleRevenueCatWebhook,
  RevenueCatConfigError,
  verifyRevenueCatWebhookAuth,
} from "@/lib/revenuecat";

export async function POST(request: Request) {
  try {
    if (!verifyRevenueCatWebhookAuth(request)) {
      return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
    }

    const body = await request.json();
    await handleRevenueCatWebhook(body);
    return NextResponse.json({ received: true });
  } catch (error) {
    if (error instanceof RevenueCatConfigError) {
      return NextResponse.json(
        { message: "RevenueCat webhook is not configured." },
        { status: 503 },
      );
    }

    console.error("revenuecat_webhook_failed", error);
    return NextResponse.json(
      { message: "Could not process webhook." },
      { status: 500 },
    );
  }
}
