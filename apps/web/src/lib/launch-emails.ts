import { createClient } from "@supabase/supabase-js";
import { Resend } from "resend";

const testFlightWelcomeEventKey = "testflight_welcome_2026_05";
const testFlightSignupEventKey = "testflight_signup_2026_05";
const testFlightLaunchOfferEventKey = "testflight_launch_offer_2026_05";
const accountWelcomeEventKey = "welcome_2026_05";
const launchTargetDate = "2026-05-22";
const devLaunchTestTargetDate = "2026-05-19";
const appStoreURL = "https://apps.apple.com/us/app/bram-workout-notes/id6767239086";

type SendEmailValues = {
  from: string;
  to: string;
  subject: string;
  text: string;
  html?: string;
};

type ResendLike = {
  emails: {
    send: (values: SendEmailValues) => Promise<unknown>;
  };
};

type QueryResult<T> = Promise<{ data: T; error: unknown | null }>;

type SupabaseFilter = {
  eq: (column: string, value: string | boolean) => SupabaseFilter;
  in: (column: string, values: string[]) => SupabaseFilter;
  is: (column: string, value: null) => SupabaseFilter;
  order: (column: string, options?: { ascending?: boolean }) => SupabaseFilter;
  limit: (count: number) => QueryResult<Record<string, unknown>[] | null>;
  maybeSingle: () => QueryResult<Record<string, unknown> | null>;
  single: () => QueryResult<Record<string, unknown> | null>;
};

type SupabaseEmailClient = {
  from: (table: string) => {
    select: (columns?: string) => SupabaseFilter;
    insert: (values: Record<string, unknown>) => Promise<{ error: unknown | null }>;
    update: (values: Record<string, unknown>) => {
      eq: (
        column: string,
        value: string,
      ) => Promise<{ error: unknown | null }>;
    };
  };
};

type LaunchEmailClients = {
  supabase?: SupabaseEmailClient;
  resend?: ResendLike;
};

export type LaunchEmailVariant = "WAITLIST_1MONTH" | "FRIENDS_LIFETIME";
type AccountDistributionChannel = "testflight" | "app_store" | "unknown";

export class LaunchEmailConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "LaunchEmailConfigError";
  }
}

let supabaseAdmin: SupabaseEmailClient | null = null;
let resendClient: Resend | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new LaunchEmailConfigError("Supabase launch email environment is missing.");
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as SupabaseEmailClient;

  return supabaseAdmin;
}

function getResend() {
  if (resendClient) {
    return resendClient;
  }

  const apiKey = process.env.RESEND_API_KEY ?? process.env.RESEND_API;
  if (!apiKey) {
    throw new LaunchEmailConfigError("Resend launch email environment is missing.");
  }

  resendClient = new Resend(apiKey);
  return resendClient;
}

function fromEmail() {
  return process.env.RESEND_FROM_EMAIL ?? "Keegan at Bram <keegan@trybram.app>";
}

function getSendError(result: unknown) {
  if (result && typeof result === "object" && "error" in result) {
    return result.error;
  }

  return null;
}

function isMissingSchemaCacheTableError(error: unknown) {
  return (
    error &&
    typeof error === "object" &&
    "code" in error &&
    (error as { code?: unknown }).code === "PGRST205"
  );
}

function emailShell(preview: string, heading: string, body: string) {
  return `<!doctype html>
<html>
  <body style="margin:0;background:#f4efe7;color:#23262c;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;">${preview}</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4efe7;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fffdf8;border:1px solid rgba(35,38,44,0.10);border-radius:24px;padding:36px;">
            <tr>
              <td>
                <div style="font-family:Georgia,serif;font-size:32px;font-weight:600;line-height:1;color:#5d5af7;margin-bottom:28px;">Bram</div>
                <h1 style="font-size:34px;line-height:1.06;margin:0 0 18px;font-weight:700;letter-spacing:0;color:#23262c;">${heading}</h1>
                ${body}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function paragraph(value: string) {
  return `<p style="font-size:17px;line-height:1.65;margin:0 0 18px;color:#4f535b;">${value}</p>`;
}

function appleOfferLink(envKey: string) {
  return process.env[envKey] ?? null;
}

function offerParagraph(label: string, url: string | null) {
  if (!url) {
    return paragraph(`${label} Use the Apple subscription offer code link or code included with this launch message.`);
  }
  return `<p style="font-size:17px;line-height:1.65;margin:0 0 18px;color:#4f535b;">${label} <a href="${url}" style="color:#5d5af7;font-weight:700;">Redeem the Apple offer code.</a></p>`;
}

function appStoreParagraph(label = "Download Bram from the App Store.") {
  return `<p style="font-size:17px;line-height:1.65;margin:0 0 18px;color:#4f535b;">${label} <a href="${appStoreURL}" style="color:#5d5af7;font-weight:700;">Open the App Store listing.</a></p>`;
}

function signature() {
  return `<p style="font-size:17px;line-height:1.5;margin:10px 0 0;color:#23262c;">Keegan<br><span style="color:#6c7078;">Founder of Bram</span></p>`;
}

function buildTestFlightWelcomeHtml() {
  const offerURL = appleOfferLink("BRAM_TESTFLIGHT_OFFER_URL");
  return emailShell(
    "Your Bram TestFlight account gets one month free.",
    "You are in.",
    [
      paragraph(
        "Thanks for testing Bram before launch. Your TestFlight account gets one month free through Apple's subscription offer-code flow.",
      ),
      offerParagraph("Start with the free month first.", offerURL),
      paragraph(
        "I am especially looking for feedback on whether writing workouts feels as easy as Notes, whether Bram understands your lifts correctly, and whether the progress stats feel useful.",
      ),
      paragraph(
        "Send anything directly to keegan@trybram.app, or comment on the Reddit post where you found the TestFlight. Critique is genuinely helpful.",
      ),
      signature(),
    ].join(""),
  );
}

function buildAccountWelcomeHtml() {
  return emailShell(
    "Welcome to Bram.",
    "Welcome to Bram.",
    [
      paragraph(
        "Thanks for using Bram. I built it for people who want workout tracking to feel as easy as writing in Notes, while still remembering lifts, PRs, streaks, and what to beat next time.",
      ),
      paragraph(
        "If you have feature requests, feedback, or anything that feels confusing, send it directly to keegan@trybram.app. I read it all.",
      ),
      paragraph("Write what you did. Bram tracks the rest."),
      signature(),
    ].join(""),
  );
}

function buildLaunchEmailHtml(variant: LaunchEmailVariant) {
  if (variant === "FRIENDS_LIFETIME") {
    return emailShell(
      "Bram launches today, and you have lifetime access.",
      "Bram launches today.",
      [
        paragraph(
          "As part of the friends and family group, you have lifetime free access to Bram. That access uses slightly adjusted AI/model limits so I can keep costs manageable while still giving you the full app experience.",
        ),
        paragraph(
          "If you want to support Bram anyway, you can subscribe from Settings in the app.",
        ),
        appStoreParagraph(),
        paragraph(
          "Download Bram from the App Store, create your account with this email, and your access should apply automatically. If anything looks wrong, email me directly at keegan@trybram.app.",
        ),
        signature(),
      ].join(""),
    );
  }

  const offerURL = appleOfferLink("BRAM_WAITLIST_OFFER_URL");
  return emailShell(
    "Bram launches today, and your first month is free.",
    "Bram launches today.",
    [
      paragraph(
        "You joined the waitlist early, so you get one month free. Bram is built for people who want workout tracking to feel as easy as writing in Notes, while still remembering lifts, PRs, streaks, and what to beat next time.",
      ),
      appStoreParagraph(),
      offerParagraph("Redeem your free month through Apple, then create your Bram account with this email.", offerURL),
      paragraph(
        "Thanks for being early. If you have feedback, send it straight to keegan@trybram.app.",
      ),
      signature(),
    ].join(""),
  );
}

function buildTestFlightLaunchOfferHtml() {
  const offerURL =
    appleOfferLink("BRAM_TESTFLIGHT_LAUNCH_OFFER_URL") ??
    appleOfferLink("BRAM_TESTFLIGHT_OFFER_URL") ??
    appleOfferLink("BRAM_WAITLIST_OFFER_URL");

  return emailShell(
    "Bram is live, and your first App Store month is free.",
    "Bram is live.",
    [
      paragraph(
        "Thanks for testing Bram in TestFlight before launch. The App Store version is now live, and your first month is free through Apple's subscription offer-code flow.",
      ),
      appStoreParagraph(),
      offerParagraph("Redeem your free month through Apple, then install Bram from the App Store.", offerURL),
      paragraph(
        "If anything feels off, send it straight to keegan@trybram.app. TestFlight feedback genuinely shaped the launch build.",
      ),
      signature(),
    ].join(""),
  );
}

async function existingEmailEvent(
  supabase: SupabaseEmailClient,
  userId: string,
  eventKey: string,
) {
  const { data, error } = await supabase
    .from("account_email_events")
    .select("id")
    .eq("user_id", userId)
    .eq("event_key", eventKey)
    .maybeSingle();

  if (error) {
    if (isMissingSchemaCacheTableError(error)) {
      console.error("account_email_events_missing_for_idempotency", error);
      return false;
    }

    throw error;
  }

  return Boolean(data);
}

async function recordEmailEvent(
  supabase: SupabaseEmailClient,
  values: {
    userId: string;
    email: string;
    eventKey: string;
    metadata?: Record<string, unknown>;
  },
) {
  const { error } = await supabase.from("account_email_events").insert({
    user_id: values.userId,
    email: values.email.toLowerCase(),
    event_key: values.eventKey,
    metadata: values.metadata ?? {},
  });

  if (error) {
    if (isMissingSchemaCacheTableError(error)) {
      console.error("account_email_events_missing_for_recording", error);
      return;
    }

    throw error;
  }
}

export async function sendTestFlightWelcomeEmail(
  values: { userId: string; email: string },
  clients: LaunchEmailClients = {},
) {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const resend = clients.resend ?? getResend();
  const email = values.email.toLowerCase();

  if (await existingEmailEvent(supabase, values.userId, testFlightWelcomeEventKey)) {
    return { status: "duplicate" as const };
  }

  const result = await resend.emails.send({
    from: fromEmail(),
    to: email,
    subject: "Welcome to the Bram TestFlight",
    text:
      `You’re in.\n\nThanks for testing Bram before launch. Your TestFlight account gets one month free through Apple's subscription offer-code flow.${appleOfferLink("BRAM_TESTFLIGHT_OFFER_URL") ? `\n\nRedeem your free month: ${appleOfferLink("BRAM_TESTFLIGHT_OFFER_URL")}` : ""}\n\nI’m especially looking for feedback on whether writing workouts feels as easy as Notes, whether Bram understands your lifts correctly, and whether the progress stats feel useful.\n\nSend anything directly to keegan@trybram.app, or comment on the Reddit post where you found the TestFlight. Critique is genuinely helpful.\n\nKeegan\nFounder of Bram`,
    html: buildTestFlightWelcomeHtml(),
  });

  const sendError = getSendError(result);
  if (sendError) {
    throw new Error("Bram TestFlight welcome email failed to send.");
  }

  await recordEmailEvent(supabase, {
    userId: values.userId,
    email,
    eventKey: testFlightWelcomeEventKey,
    metadata: { offer_source: "apple_offer_code" },
  });

  return { status: "sent" as const };
}

export async function sendAccountWelcomeEmail(
  values: {
    userId: string;
    email: string;
    distributionChannel?: AccountDistributionChannel | null;
  },
  clients: LaunchEmailClients = {},
) {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const resend = clients.resend ?? getResend();
  const email = values.email.toLowerCase();

  const welcomeAlreadySent = await existingEmailEvent(
    supabase,
    values.userId,
    accountWelcomeEventKey,
  );

  if (!welcomeAlreadySent) {
    const result = await resend.emails.send({
      from: fromEmail(),
      to: email,
      subject: "Welcome to Bram",
      text:
        "Welcome to Bram.\n\nThanks for using Bram. I built it for people who want workout tracking to feel as easy as writing in Notes, while still remembering lifts, PRs, streaks, and what to beat next time.\n\nIf you have feature requests, feedback, or anything that feels confusing, send it directly to keegan@trybram.app. I read it all.\n\nWrite what you did. Bram tracks the rest.\n\nKeegan\nFounder of Bram",
      html: buildAccountWelcomeHtml(),
    });

    const sendError = getSendError(result);
    if (sendError) {
      throw new Error("Bram welcome email failed to send.");
    }

    await recordEmailEvent(supabase, {
      userId: values.userId,
      email,
      eventKey: accountWelcomeEventKey,
      metadata: {
        distribution_channel: values.distributionChannel ?? "unknown",
      },
    });
  }

  if (values.distributionChannel === "testflight") {
    await recordTestFlightSignup({ userId: values.userId, email }, { supabase });
  }

  return { status: welcomeAlreadySent ? ("duplicate" as const) : ("sent" as const) };
}

export async function recordTestFlightSignup(
  values: { userId: string; email: string },
  clients: Pick<LaunchEmailClients, "supabase"> = {},
) {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const email = values.email.toLowerCase();

  if (await existingEmailEvent(supabase, values.userId, testFlightSignupEventKey)) {
    return { status: "duplicate" as const };
  }

  await recordEmailEvent(supabase, {
    userId: values.userId,
    email,
    eventKey: testFlightSignupEventKey,
    metadata: { distribution_channel: "testflight" },
  });

  return { status: "recorded" as const };
}

async function hasLifetimeFriendAccess(
  supabase: SupabaseEmailClient,
  email: string,
) {
  const promoQuery = supabase
    .from("account_promo_eligibilities")
    .select("id")
    .eq("email", email)
    .in("grant_kind", ["FRIENDS_DISCOUNT", "FOUNDER_LIFETIME"]);

  const { data, error } = await promoQuery.limit(1);
  if (error) {
    throw error;
  }
  if (Array.isArray(data) && data.length > 0) {
    return true;
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("user_id")
    .eq("email", email)
    .maybeSingle();

  if (profileError) {
    throw profileError;
  }

  const userId = profile?.user_id;
  if (typeof userId !== "string") {
    return false;
  }

  const { data: entitlement, error: entitlementError } = await supabase
    .from("account_entitlements")
    .select("active_promo_kind")
    .eq("user_id", userId)
    .maybeSingle();

  if (entitlementError) {
    throw entitlementError;
  }

  return (
    entitlement?.active_promo_kind === "FRIENDS_DISCOUNT" ||
    entitlement?.active_promo_kind === "FOUNDER_LIFETIME"
  );
}

export async function launchEmailVariantForAddress(
  email: string,
  clients: Pick<LaunchEmailClients, "supabase"> = {},
): Promise<LaunchEmailVariant> {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  return (await hasLifetimeFriendAccess(supabase, email.toLowerCase()))
    ? "FRIENDS_LIFETIME"
    : "WAITLIST_1MONTH";
}

async function sendLaunchEmail(
  email: string,
  variant: LaunchEmailVariant,
  resend: ResendLike,
) {
  const subject =
    variant === "FRIENDS_LIFETIME"
      ? "Bram launches today — you have lifetime access"
      : "Bram launches today — your first month is free";
  const text =
    variant === "FRIENDS_LIFETIME"
      ? `Bram launches today.\n\nAs part of the friends and family group, you have lifetime free access to Bram. That access uses slightly adjusted AI/model limits so I can keep costs manageable while still giving you the full app experience.\n\nIf you want to support Bram anyway, you can subscribe from Settings in the app.\n\nDownload Bram from the App Store: ${appStoreURL}\n\nCreate your account with this email, and your access should apply automatically. If anything looks wrong, email me directly at keegan@trybram.app.\n\nKeegan\nFounder of Bram`
      : `Bram launches today.\n\nYou joined the waitlist early, so you get one month free. Bram is built for people who want workout tracking to feel as easy as writing in Notes, while still remembering lifts, PRs, streaks, and what to beat next time.\n\nDownload Bram from the App Store: ${appStoreURL}${appleOfferLink("BRAM_WAITLIST_OFFER_URL") ? `\n\nRedeem your free month through Apple: ${appleOfferLink("BRAM_WAITLIST_OFFER_URL")}` : "\n\nRedeem your free month through the Apple subscription offer code link or code included with this email."}\n\nThanks for being early. If you have feedback, send it straight to keegan@trybram.app.\n\nKeegan\nFounder of Bram`;

  const result = await resend.emails.send({
    from: fromEmail(),
    to: email,
    subject,
    text,
    html: buildLaunchEmailHtml(variant),
  });

  const sendError = getSendError(result);
  if (sendError) {
    throw new Error("Bram launch email failed to send.");
  }
}

async function sendTestFlightLaunchOfferEmail(email: string, resend: ResendLike) {
  const offerURL =
    appleOfferLink("BRAM_TESTFLIGHT_LAUNCH_OFFER_URL") ??
    appleOfferLink("BRAM_TESTFLIGHT_OFFER_URL") ??
    appleOfferLink("BRAM_WAITLIST_OFFER_URL");
  const result = await resend.emails.send({
    from: fromEmail(),
    to: email,
    subject: "Bram is live — your first month is free",
    text:
      `Bram is live.\n\nThanks for testing Bram in TestFlight before launch. The App Store version is now live, and your first month is free through Apple's subscription offer-code flow.\n\nDownload Bram from the App Store: ${appStoreURL}${offerURL ? `\n\nRedeem your free month through Apple: ${offerURL}` : "\n\nRedeem your free month through the Apple subscription offer code link or code included with this email."}\n\nIf anything feels off, send it straight to keegan@trybram.app. TestFlight feedback genuinely shaped the launch build.\n\nKeegan\nFounder of Bram`,
    html: buildTestFlightLaunchOfferHtml(),
  });

  const sendError = getSendError(result);
  if (sendError) {
    throw new Error("Bram TestFlight launch offer email failed to send.");
  }
}

async function sendIdempotentLaunchEmail(
  values: {
    userId: string;
    email: string;
    variant: LaunchEmailVariant;
    eventKey: string;
    metadata?: Record<string, unknown>;
  },
  clients: { supabase: SupabaseEmailClient; resend: ResendLike },
) {
  if (await existingEmailEvent(clients.supabase, values.userId, values.eventKey)) {
    return "duplicate" as const;
  }

  await sendLaunchEmail(values.email, values.variant, clients.resend);
  await recordEmailEvent(clients.supabase, {
    userId: values.userId,
    email: values.email,
    eventKey: values.eventKey,
    metadata: values.metadata,
  });

  return "sent" as const;
}

async function sendIdempotentTestFlightLaunchOfferEmail(
  values: {
    userId: string;
    email: string;
    eventKey: string;
    metadata?: Record<string, unknown>;
  },
  clients: { supabase: SupabaseEmailClient; resend: ResendLike },
) {
  if (await existingEmailEvent(clients.supabase, values.userId, values.eventKey)) {
    return "duplicate" as const;
  }

  await sendTestFlightLaunchOfferEmail(values.email, clients.resend);
  await recordEmailEvent(clients.supabase, {
    userId: values.userId,
    email: values.email,
    eventKey: values.eventKey,
    metadata: values.metadata,
  });

  return "sent" as const;
}

function parseBatchSize(value: string | undefined) {
  const parsed = value ? Number.parseInt(value, 10) : 100;
  if (!Number.isFinite(parsed)) {
    return 100;
  }

  return Math.max(1, Math.min(parsed, 250));
}

export function verifyCronSecret(request: Request) {
  const expected = process.env.CRON_SECRET;
  return Boolean(expected) && request.headers.get("authorization") === `Bearer ${expected}`;
}

export function isLaunchEmailEnabled(now = new Date()) {
  return (
    process.env.LAUNCH_DAY_EMAIL_ENABLED === "true" &&
    now.toISOString().slice(0, 10) === launchTargetDate
  );
}

export function isDevLaunchEmailTestEnabled(now = new Date()) {
  return now.toISOString().slice(0, 10) === devLaunchTestTargetDate;
}

export async function sendLaunchDayWaitlistEmails(
  options: { dryRun?: boolean; now?: Date } = {},
  clients: LaunchEmailClients = {},
) {
  if (!isLaunchEmailEnabled(options.now)) {
    return { status: "disabled" as const, sent: 0, failed: 0, skipped: 0 };
  }

  const supabase = clients.supabase ?? getSupabaseAdmin();
  const resend = clients.resend ?? getResend();
  const batchSize = parseBatchSize(process.env.LAUNCH_EMAIL_BATCH_SIZE);

  const pendingQuery = supabase
    .from("waitlist_signups")
    .select("id,email")
    .is("launch_email_sent_at", null);

  const { data, error } = await pendingQuery
    .order("created_at", { ascending: true })
    .limit(batchSize);

  if (error) {
    throw error;
  }

  const rows = Array.isArray(data) ? data : [];
  let sent = 0;
  let failed = 0;
  let skipped = 0;

  for (const row of rows) {
    const id = typeof row.id === "string" ? row.id : null;
    const email = typeof row.email === "string" ? row.email.toLowerCase() : null;
    if (!id || !email) {
      skipped += 1;
      continue;
    }

    try {
      const variant = await launchEmailVariantForAddress(email, { supabase });
      if (!options.dryRun) {
        await sendLaunchEmail(email, variant, resend);
        const { error: updateError } = await supabase
          .from("waitlist_signups")
          .update({
            launch_email_sent_at: new Date().toISOString(),
            launch_email_variant: variant,
            launch_email_error: null,
          })
          .eq("id", id);

        if (updateError) {
          throw updateError;
        }
      }
      sent += 1;
    } catch (error) {
      failed += 1;
      const message = error instanceof Error ? error.message : "Unknown launch email error.";
      if (!options.dryRun) {
        await supabase
          .from("waitlist_signups")
          .update({ launch_email_error: message })
          .eq("id", id);
      }
    }
  }

  return {
    status: options.dryRun ? ("dry-run" as const) : ("sent" as const),
    sent,
    failed,
    skipped,
  };
}

export async function sendTestFlightLaunchOfferEmails(
  options: { dryRun?: boolean; now?: Date } = {},
  clients: LaunchEmailClients = {},
) {
  if (!isLaunchEmailEnabled(options.now)) {
    return { status: "disabled" as const, sent: 0, failed: 0, skipped: 0 };
  }

  const supabase = clients.supabase ?? getSupabaseAdmin();
  const resend = clients.resend ?? getResend();
  const batchSize = parseBatchSize(process.env.LAUNCH_EMAIL_BATCH_SIZE);

  const { data, error } = await supabase
    .from("account_email_events")
    .select("user_id,email")
    .eq("event_key", testFlightSignupEventKey)
    .order("created_at", { ascending: true })
    .limit(batchSize);

  if (error) {
    throw error;
  }

  const rows = Array.isArray(data) ? data : [];
  let sent = 0;
  let failed = 0;
  let skipped = 0;

  for (const row of rows) {
    const userId = typeof row.user_id === "string" ? row.user_id : null;
    const email = typeof row.email === "string" ? row.email.toLowerCase() : null;
    if (!userId || !email) {
      skipped += 1;
      continue;
    }

    try {
      if (!options.dryRun) {
        const result = await sendIdempotentTestFlightLaunchOfferEmail(
          {
            userId,
            email,
            eventKey: testFlightLaunchOfferEventKey,
            metadata: { source: "testflight_signup" },
          },
          { supabase, resend },
        );
        if (result === "duplicate") {
          skipped += 1;
          continue;
        }
      }
      sent += 1;
    } catch (error) {
      console.error("testflight_launch_offer_email_failed", { email, error });
      failed += 1;
    }
  }

  return {
    status: options.dryRun ? ("dry-run" as const) : ("sent" as const),
    sent,
    failed,
    skipped,
  };
}

export async function sendDevLaunchEmailTest(
  options: { dryRun?: boolean; now?: Date } = {},
  clients: LaunchEmailClients = {},
) {
  if (!isDevLaunchEmailTestEnabled(options.now)) {
    return { status: "disabled" as const, sent: 0, failed: 0, skipped: 0 };
  }

  const supabase = clients.supabase ?? getSupabaseAdmin();
  const resend = clients.resend ?? getResend();
  const batchSize = parseBatchSize(process.env.LAUNCH_EMAIL_BATCH_SIZE);
  const { data, error } = await supabase
    .from("account_snapshot")
    .select("user_id,email")
    .eq("is_developer", true)
    .limit(batchSize);

  if (error) {
    throw error;
  }

  const rows = Array.isArray(data) ? data : [];
  let sent = 0;
  let failed = 0;
  let skipped = 0;

  for (const row of rows) {
    const userId = typeof row.user_id === "string" ? row.user_id : null;
    const email = typeof row.email === "string" ? row.email.toLowerCase() : null;
    if (!userId || !email) {
      skipped += 1;
      continue;
    }

    for (const variant of ["WAITLIST_1MONTH", "FRIENDS_LIFETIME"] as const) {
      try {
        if (!options.dryRun) {
          const eventKey = `launch_email_test_dev_2026_05_19_${variant.toLowerCase()}`;
          const result = await sendIdempotentLaunchEmail(
            {
              userId,
              email,
              variant,
              eventKey,
              metadata: { route: "test-launch-email-dev" },
            },
            { supabase, resend },
          );

          if (result === "duplicate") {
            skipped += 1;
            continue;
          }
        }
        sent += 1;
      } catch (error) {
        console.error("dev_launch_email_test_failed", { email, variant, error });
        failed += 1;
      }
    }
  }

  return {
    status: options.dryRun ? ("dry-run" as const) : ("sent" as const),
    sent,
    failed,
    skipped,
  };
}
