import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";
import { sendAccountWelcomeEmail } from "@/lib/launch-emails";

function bearerToken(request: Request) {
  const header = request.headers.get("authorization") ?? "";
  if (!header.toLowerCase().startsWith("bearer ")) {
    return null;
  }
  return header.slice("bearer ".length).trim();
}

function supabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new Error("Supabase welcome email environment is missing.");
  }

  return createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export async function POST(request: Request) {
  try {
    const token = bearerToken(request);
    if (!token) {
      return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
    }

    const supabase = supabaseAdmin();
    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data.user) {
      return NextResponse.json({ message: "Unauthorized." }, { status: 401 });
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("email")
      .eq("user_id", data.user.id)
      .maybeSingle();

    const email =
      typeof profile?.email === "string"
        ? profile.email
        : data.user.email;

    if (!email) {
      return NextResponse.json(
        { message: "Account email was not found." },
        { status: 404 },
      );
    }

    const result = await sendAccountWelcomeEmail(
      { userId: data.user.id, email },
      { supabase: supabase as never },
    );
    return NextResponse.json(result);
  } catch (error) {
    console.error("account_welcome_email_failed", error);
    return NextResponse.json(
      { message: "Could not send welcome email." },
      { status: 500 },
    );
  }
}
