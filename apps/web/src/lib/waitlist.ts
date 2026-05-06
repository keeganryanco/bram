import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { Resend } from "resend";
import { z } from "zod";

const emailSchema = z.string().trim().toLowerCase().email();

export type WaitlistSignupInput = {
  email: string;
  source?: string | null;
  userAgent?: string | null;
  referrer?: string | null;
};

export type WaitlistResult = {
  status: "created" | "duplicate";
};

type WaitlistInsertError = {
  code?: string;
  message?: string;
};

type SupabaseLike = {
  from: (table: "waitlist_signups") => {
    insert: (values: Record<string, unknown>) => Promise<{
      error: WaitlistInsertError | null;
    }>;
  };
};

type ResendLike = {
  emails: {
    send: (values: {
      from: string;
      to: string;
      subject: string;
      text: string;
    }) => Promise<unknown>;
  };
};

type WaitlistClients = {
  supabase?: SupabaseLike;
  resend?: ResendLike;
};

export class WaitlistConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WaitlistConfigError";
  }
}

let supabaseClient: SupabaseLike | null = null;
let resendClient: Resend | null = null;

export function normalizeEmail(value: unknown) {
  return emailSchema.safeParse(value);
}

function getSupabase() {
  if (supabaseClient) {
    return supabaseClient;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new WaitlistConfigError("Supabase waitlist environment is missing.");
  }

  const client: SupabaseClient = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  supabaseClient = {
    from: () => ({
      insert: async (values) => {
        const { error } = await client.from("waitlist_signups").insert(values);
        return { error };
      },
    }),
  };

  return supabaseClient;
}

function getResend() {
  if (resendClient) {
    return resendClient;
  }

  const apiKey = process.env.RESEND_API_KEY;

  if (!apiKey) {
    throw new WaitlistConfigError("Resend environment is missing.");
  }

  resendClient = new Resend(apiKey);
  return resendClient;
}

export async function joinWaitlist(
  input: WaitlistSignupInput,
  clients: WaitlistClients = {},
): Promise<WaitlistResult> {
  const supabase = clients.supabase ?? getSupabase();
  const resend = clients.resend ?? getResend();
  const fromEmail = process.env.RESEND_FROM_EMAIL ?? "Bram <support@trybram.app>";

  const { error } = await supabase.from("waitlist_signups").insert({
    email: input.email,
    source: input.source ?? "website",
    user_agent: input.userAgent ?? null,
    referrer: input.referrer ?? null,
  });

  if (error) {
    if ("code" in error && error.code === "23505") {
      return { status: "duplicate" };
    }

    throw error;
  }

  await resend.emails.send({
    from: fromEmail,
    to: input.email,
    subject: "You are on the Bram waitlist",
    text:
      "Thanks for joining the Bram waitlist. Bram is a notes-first workout tracker for writing naturally and keeping progress organized. We will send early access updates here.",
  });

  const notifyEmail = process.env.WAITLIST_NOTIFY_EMAIL;
  if (notifyEmail) {
    await resend.emails.send({
      from: fromEmail,
      to: notifyEmail,
      subject: "New Bram waitlist signup",
      text: `${input.email} joined the Bram waitlist.`,
    });
  }

  return { status: "created" };
}
