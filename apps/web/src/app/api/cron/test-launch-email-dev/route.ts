import { NextResponse } from "next/server";
import {
  sendDevLaunchEmailTest,
  verifyCronSecret,
} from "@/lib/launch-emails";

export async function GET(request: Request) {
  if (!verifyCronSecret(request)) {
    return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
  }

  const url = new URL(request.url);
  const dryRun = url.searchParams.get("dryRun") === "1";

  try {
    const result = await sendDevLaunchEmailTest({ dryRun });
    return NextResponse.json(result);
  } catch (error) {
    console.error("test_launch_email_dev_failed", error);
    return NextResponse.json(
      { message: "Could not send dev launch email test." },
      { status: 500 },
    );
  }
}
