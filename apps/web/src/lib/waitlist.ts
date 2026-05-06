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
    update: (values: Record<string, unknown>) => {
      eq: (
        column: "email",
        value: string,
      ) => Promise<{ error: WaitlistInsertError | null }>;
    };
  };
};

type ResendLike = {
  emails: {
    send: (values: {
      from: string;
      to: string;
      subject: string;
      text: string;
      html?: string;
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
      update: (values) => ({
        eq: async (column, value) => {
          const { error } = await client
            .from("waitlist_signups")
            .update(values)
            .eq(column, value);
          return { error };
        },
      }),
    }),
  };

  return supabaseClient;
}

function getResend() {
  if (resendClient) {
    return resendClient;
  }

  const apiKey = process.env.RESEND_API_KEY ?? process.env.RESEND_API;

  if (!apiKey) {
    throw new WaitlistConfigError("Resend environment is missing.");
  }

  resendClient = new Resend(apiKey);
  return resendClient;
}

function buildWelcomeEmailHtml() {
  return `<!doctype html>
<html>
  <body style="margin:0;background:#f4efe7;color:#23262c;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;">You are officially on the Bram waitlist.</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4efe7;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fffdf8;border:1px solid rgba(35,38,44,0.10);border-radius:24px;padding:36px;">
            <tr>
              <td>
                <div style="font-family:Georgia,serif;font-size:32px;font-weight:600;line-height:1;color:#5d5af7;margin-bottom:28px;">Bram</div>
                <h1 style="font-size:34px;line-height:1.06;margin:0 0 18px;font-weight:700;letter-spacing:0;color:#23262c;">You are on the waitlist.</h1>
                <p style="font-size:17px;line-height:1.65;margin:0 0 18px;color:#4f535b;">Bram is the simplest workout tracker ever: as easy as Notes, with the insights of a personal trainer.</p>
                <p style="font-size:17px;line-height:1.65;margin:0 0 18px;color:#4f535b;">You will hear more about the app in the next 2-3 weeks, along with a special surprise for believing in Bram this early.</p>
                <p style="font-size:17px;line-height:1.65;margin:0 0 28px;color:#4f535b;">Thanks for helping shape it.</p>
                <p style="font-size:17px;line-height:1.5;margin:0;color:#23262c;">Keegan<br><span style="color:#6c7078;">Founder of Bram</span></p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function getSendError(result: unknown) {
  if (result && typeof result === "object" && "error" in result) {
    return result.error;
  }

  return null;
}

export async function joinWaitlist(
  input: WaitlistSignupInput,
  clients: WaitlistClients = {},
): Promise<WaitlistResult> {
  const supabase = clients.supabase ?? getSupabase();
  const resend = clients.resend ?? getResend();
  const fromEmail =
    process.env.RESEND_FROM_EMAIL ?? "Keegan at Bram <keegan@trybram.app>";

  const { error } = await supabase.from("waitlist_signups").insert({
    email: input.email,
    source: input.source ?? "website",
    user_agent: input.userAgent ?? null,
    referrer: input.referrer ?? null,
    founder_discount_eligible: true,
  });

  if (error) {
    if ("code" in error && error.code === "23505") {
      return { status: "duplicate" };
    }

    throw error;
  }

  const welcomeResult = await resend.emails.send({
    from: fromEmail,
    to: input.email,
    subject: "You are on the Bram waitlist",
    text:
      "You are officially on the Bram waitlist. Bram is the simplest workout tracker ever: as easy as Notes, with the insights of a personal trainer. You will hear more about the app in the next 2-3 weeks, along with a special surprise for believing in Bram this early. Thanks for helping shape it.\n\nKeegan\nFounder of Bram",
    html: buildWelcomeEmailHtml(),
  });

  const sendError = getSendError(welcomeResult);
  if (sendError) {
    throw new Error("Bram welcome email failed to send.");
  }

  const { error: updateError } = await supabase
    .from("waitlist_signups")
    .update({ welcome_email_sent_at: new Date().toISOString() })
    .eq("email", input.email);

  if (updateError) {
    console.error("waitlist_welcome_email_timestamp_failed", updateError);
  }

  const notifyEmail = process.env.WAITLIST_NOTIFY_EMAIL;
  if (notifyEmail) {
    const notifyResult = await resend.emails.send({
      from: fromEmail,
      to: notifyEmail,
      subject: "New Bram waitlist signup",
      text: `${input.email} joined the Bram waitlist.`,
    });

    const notifyError = getSendError(notifyResult);
    if (notifyError) {
      console.error("waitlist_notify_email_failed", notifyError);
    }
  }

  return { status: "created" };
}
