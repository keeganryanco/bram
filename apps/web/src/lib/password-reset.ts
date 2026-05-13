import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { Resend } from "resend";
import { z } from "zod";

const emailSchema = z.string().trim().toLowerCase().email();

type PasswordResetGenerateLinkParams = {
  type: "recovery";
  email: string;
  options: {
    redirectTo: string;
  };
};

type PasswordResetGenerateLinkResult = {
  data: {
    properties?: {
      action_link?: string | null;
    } | null;
  } | null;
  error: unknown | null;
};

type PasswordResetSupabaseLike = {
  auth: {
    admin: {
      generateLink: (
        params: PasswordResetGenerateLinkParams,
      ) => Promise<PasswordResetGenerateLinkResult>;
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

type PasswordResetClients = {
  supabase?: PasswordResetSupabaseLike;
  resend?: ResendLike;
};

export class PasswordResetConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PasswordResetConfigError";
  }
}

let supabaseClient: SupabaseClient | null = null;
let resendClient: Resend | null = null;

export function normalizePasswordResetEmail(value: unknown) {
  return emailSchema.safeParse(value);
}

function getSiteURL() {
  return (
    process.env.NEXT_PUBLIC_SITE_URL ??
    process.env.VERCEL_PROJECT_PRODUCTION_URL?.replace(/^/, "https://") ??
    "https://trybram.app"
  ).replace(/\/$/, "");
}

function getSupabase() {
  if (supabaseClient) {
    return supabaseClient;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new PasswordResetConfigError(
      "Supabase password reset environment is missing.",
    );
  }

  supabaseClient = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  return supabaseClient;
}

function getResend() {
  if (resendClient) {
    return resendClient;
  }

  const apiKey = process.env.RESEND_API_KEY ?? process.env.RESEND_API;

  if (!apiKey) {
    throw new PasswordResetConfigError("Resend environment is missing.");
  }

  resendClient = new Resend(apiKey);
  return resendClient;
}

function getActionLink(result: PasswordResetGenerateLinkResult) {
  if (result.error) {
    throw result.error;
  }

  return result.data?.properties?.action_link;
}

function getSendError(result: unknown) {
  if (result && typeof result === "object" && "error" in result) {
    return result.error;
  }

  return null;
}

function buildPasswordResetEmailHtml(actionLink: string) {
  return `<!doctype html>
<html>
  <body style="margin:0;background:#f4efe7;color:#23262c;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;">Reset your Bram password.</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4efe7;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fffdf8;border:1px solid rgba(35,38,44,0.10);border-radius:24px;padding:36px;">
            <tr>
              <td>
                <div style="font-family:Georgia,serif;font-size:32px;font-weight:600;line-height:1;color:#5d5af7;margin-bottom:28px;">Bram</div>
                <h1 style="font-size:34px;line-height:1.06;margin:0 0 18px;font-weight:700;letter-spacing:0;color:#23262c;">Reset your password.</h1>
                <p style="font-size:17px;line-height:1.65;margin:0 0 24px;color:#4f535b;">Use this private link to choose a new Bram password. The link expires soon and only works for this account.</p>
                <a href="${actionLink}" style="display:inline-block;background:#5d5af7;color:#fffdf8;text-decoration:none;border-radius:999px;padding:13px 20px;font-size:16px;font-weight:600;">Reset password</a>
                <p style="font-size:14px;line-height:1.55;margin:26px 0 0;color:#6c7078;">If you did not request this, you can ignore this email.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

export async function sendPasswordResetEmail(
  email: string,
  clients: PasswordResetClients = {},
) {
  const supabase = clients.supabase ?? getSupabase();
  const resend = clients.resend ?? getResend();
  const fromEmail =
    process.env.RESEND_FROM_EMAIL ?? "Keegan at Bram <keegan@trybram.app>";
  const redirectTo = `${getSiteURL()}/reset-password`;

  const linkResult = await supabase.auth.admin.generateLink({
    type: "recovery",
    email,
    options: {
      redirectTo,
    },
  });

  const actionLink = getActionLink(linkResult);
  if (!actionLink) {
    throw new Error("Supabase password reset link was not returned.");
  }

  const sendResult = await resend.emails.send({
    from: fromEmail,
    to: email,
    subject: "Reset your Bram password",
    text: `Reset your Bram password: ${actionLink}\n\nIf you did not request this, you can ignore this email.`,
    html: buildPasswordResetEmailHtml(actionLink),
  });

  const sendError = getSendError(sendResult);
  if (sendError) {
    throw new Error("Bram password reset email failed to send.");
  }
}
