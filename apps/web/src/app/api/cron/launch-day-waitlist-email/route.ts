import { NextResponse } from "next/server";
import {
  sendLaunchDayWaitlistEmails,
  verifyCronSecret,
} from "@/lib/launch-emails";

export async function GET(request: Request) {
  if (!verifyCronSecret(request)) {
    return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
  }

  const url = new URL(request.url);
  const dryRun = url.searchParams.get("dryRun") === "1";

  try {
    const result = await sendLaunchDayWaitlistEmails({ dryRun });
    return NextResponse.json(result);
  } catch (error) {
    console.error("launch_day_waitlist_email_failed", error);
    return NextResponse.json(
      { message: "Could not send launch email batch." },
      { status: 500 },
    );
  }
}
