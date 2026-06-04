import { NextResponse } from "next/server";
import { tiktokAppEventsConfig } from "@/lib/tiktok-events";

export async function GET() {
  return NextResponse.json(tiktokAppEventsConfig(), {
    headers: {
      "Cache-Control": "public, max-age=300, stale-while-revalidate=3600",
    },
  });
}
