import { afterEach, describe, expect, it, vi } from "vitest";
import {
  isLaunchEmailEnabled,
  isDevLaunchEmailTestEnabled,
  launchEmailVariantForAddress,
  sendAccountWelcomeEmail,
  sendDevLaunchEmailTest,
  sendLaunchDayWaitlistEmails,
  sendTestFlightWelcomeEmail,
  verifyCronSecret,
} from "./launch-emails";

const userId = "11111111-1111-4111-8111-111111111111";

function resendMock(sendError: unknown | null = null) {
  return {
    emails: {
      send: vi.fn(async () =>
        sendError ? { data: null, error: sendError } : { data: { id: "email_1" }, error: null },
      ),
    },
  };
}

function makeFilter(table: string, state: MockState) {
  const filter = {
    eq: vi.fn(() => filter),
    in: vi.fn(() => filter),
    is: vi.fn(() => filter),
    order: vi.fn(() => filter),
    limit: vi.fn(async () => {
      if (table === "waitlist_signups") {
        return { data: state.waitlistRows, error: null };
      }

      if (table === "account_snapshot") {
        return { data: state.devAccountRows, error: null };
      }

      if (table === "account_promo_eligibilities") {
        return { data: state.friendPromo ? [{ id: "promo_1" }] : [], error: null };
      }

      return { data: [], error: null };
    }),
    maybeSingle: vi.fn(async () => {
      if (table === "account_email_events") {
        return {
          data: state.existingEmailEvent ? { id: "event_1" } : null,
          error: state.emailEventMissing
            ? {
                code: "PGRST205",
                message:
                  "Could not find the table 'public.account_email_events' in the schema cache",
              }
            : null,
        };
      }

      if (table === "profiles") {
        return {
          data: state.profileUserId ? { user_id: state.profileUserId } : null,
          error: null,
        };
      }

      if (table === "account_entitlements") {
        return {
          data: state.activePromoKind
            ? { active_promo_kind: state.activePromoKind }
            : null,
          error: null,
        };
      }

      return { data: null, error: null };
    }),
    single: vi.fn(async () => ({ data: null, error: null })),
  };

  return filter;
}

type MockState = {
  existingEmailEvent?: boolean;
  emailEventMissing?: boolean;
  friendPromo?: boolean;
  profileUserId?: string | null;
  activePromoKind?: string | null;
  waitlistRows?: Record<string, unknown>[];
  devAccountRows?: Record<string, unknown>[];
  updateError?: unknown | null;
};

function supabaseMock(state: MockState = {}) {
  const inserts: { table: string; values: Record<string, unknown> }[] = [];
  const updates: { table: string; values: Record<string, unknown>; eq: unknown[] }[] = [];

  return {
    client: {
      from: vi.fn((table: string) => ({
        select: vi.fn(() => makeFilter(table, state)),
        insert: vi.fn(async (values: Record<string, unknown>) => {
          inserts.push({ table, values });
          return {
            error:
              state.emailEventMissing && table === "account_email_events"
                ? {
                    code: "PGRST205",
                    message:
                      "Could not find the table 'public.account_email_events' in the schema cache",
                  }
                : null,
          };
        }),
        update: vi.fn((values: Record<string, unknown>) => ({
          eq: vi.fn(async (...eq: unknown[]) => {
            updates.push({ table, values, eq });
            return { error: state.updateError ?? null };
          }),
        })),
      })),
    },
    inserts,
    updates,
  };
}

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("TestFlight welcome email", () => {
  it("sends once and records an account email event", async () => {
    const supabase = supabaseMock();
    const resend = resendMock();

    const result = await sendTestFlightWelcomeEmail(
      { userId, email: "Tester@TryBram.App" },
      { supabase: supabase.client, resend },
    );

    expect(result.status).toBe("sent");
    expect(resend.emails.send).toHaveBeenCalledTimes(1);
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: "tester@trybram.app",
        subject: "Welcome to the Bram TestFlight",
        text: expect.stringContaining("Apple's subscription offer-code flow"),
      }),
    );
    expect(supabase.inserts[0]).toMatchObject({
      table: "account_email_events",
      values: {
        user_id: userId,
        email: "tester@trybram.app",
        event_key: "testflight_welcome_2026_05",
      },
    });
  });

  it("does not resend when the event already exists", async () => {
    const supabase = supabaseMock({ existingEmailEvent: true });
    const resend = resendMock();

    const result = await sendTestFlightWelcomeEmail(
      { userId, email: "tester@trybram.app" },
      { supabase: supabase.client, resend },
    );

    expect(result.status).toBe("duplicate");
    expect(resend.emails.send).not.toHaveBeenCalled();
    expect(supabase.inserts).toHaveLength(0);
  });

  it("still sends when the email event table has not been migrated yet", async () => {
    const supabase = supabaseMock({ emailEventMissing: true });
    const resend = resendMock();

    const result = await sendTestFlightWelcomeEmail(
      { userId, email: "tester@trybram.app" },
      { supabase: supabase.client, resend },
    );

    expect(result.status).toBe("sent");
    expect(resend.emails.send).toHaveBeenCalledTimes(1);
  });
});

describe("account welcome email", () => {
  it("sends once and records an account email event", async () => {
    const supabase = supabaseMock();
    const resend = resendMock();

    const result = await sendAccountWelcomeEmail(
      { userId, email: "NewUser@TryBram.App" },
      { supabase: supabase.client, resend },
    );

    expect(result.status).toBe("sent");
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: "newuser@trybram.app",
        subject: "Welcome to Bram",
        text: expect.stringContaining("keegan@trybram.app"),
      }),
    );
    expect(supabase.inserts[0]).toMatchObject({
      table: "account_email_events",
      values: {
        user_id: userId,
        email: "newuser@trybram.app",
        event_key: "welcome_2026_05",
      },
    });
  });

  it("does not resend when the welcome event already exists", async () => {
    const supabase = supabaseMock({ existingEmailEvent: true });
    const resend = resendMock();

    const result = await sendAccountWelcomeEmail(
      { userId, email: "newuser@trybram.app" },
      { supabase: supabase.client, resend },
    );

    expect(result.status).toBe("duplicate");
    expect(resend.emails.send).not.toHaveBeenCalled();
  });
});

describe("launch day waitlist email", () => {
  it("rejects invalid cron authorization", () => {
    vi.stubEnv("CRON_SECRET", "cron-secret");
    const request = new Request("https://www.trybram.app/api/cron", {
      headers: { authorization: "Bearer wrong" },
    });

    expect(verifyCronSecret(request)).toBe(false);
  });

  it("only enables on launch day when configured", () => {
    vi.stubEnv("LAUNCH_DAY_EMAIL_ENABLED", "true");

    expect(isLaunchEmailEnabled(new Date("2026-05-22T12:00:00.000Z"))).toBe(true);
    expect(isLaunchEmailEnabled(new Date("2026-05-23T12:00:00.000Z"))).toBe(false);
  });

  it("only enables the dev launch email test on May 19", () => {
    expect(isDevLaunchEmailTestEnabled(new Date("2026-05-19T20:50:00.000Z"))).toBe(true);
    expect(isDevLaunchEmailTestEnabled(new Date("2026-05-20T20:50:00.000Z"))).toBe(false);
  });

  it("uses the friends/family variant for lifetime promo eligibility", async () => {
    const supabase = supabaseMock({ friendPromo: true });

    await expect(
      launchEmailVariantForAddress("friend@trybram.app", {
        supabase: supabase.client,
      }),
    ).resolves.toBe("FRIENDS_LIFETIME");
  });

  it("sends launch emails and marks successful waitlist rows", async () => {
    vi.stubEnv("LAUNCH_DAY_EMAIL_ENABLED", "true");
    const supabase = supabaseMock({
      waitlistRows: [{ id: "waitlist_1", email: "lift@trybram.app" }],
    });
    const resend = resendMock();

    const result = await sendLaunchDayWaitlistEmails(
      { now: new Date("2026-05-22T12:00:00.000Z") },
      { supabase: supabase.client, resend },
    );

    expect(result).toMatchObject({ status: "sent", sent: 1, failed: 0 });
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: "lift@trybram.app",
        subject: "Bram launches today — your first month is free",
      }),
    );
    expect(supabase.updates[0]).toMatchObject({
      table: "waitlist_signups",
      values: {
        launch_email_sent_at: expect.any(String),
        launch_email_variant: "WAITLIST_1MONTH",
        launch_email_error: null,
      },
    });
  });

  it("records send failures without marking rows as sent", async () => {
    vi.stubEnv("LAUNCH_DAY_EMAIL_ENABLED", "true");
    const supabase = supabaseMock({
      waitlistRows: [{ id: "waitlist_1", email: "lift@trybram.app" }],
    });
    const resend = resendMock({ message: "domain failed" });

    const result = await sendLaunchDayWaitlistEmails(
      { now: new Date("2026-05-22T12:00:00.000Z") },
      { supabase: supabase.client, resend },
    );

    expect(result).toMatchObject({ status: "sent", sent: 0, failed: 1 });
    expect(supabase.updates[0]).toMatchObject({
      table: "waitlist_signups",
      values: {
        launch_email_error: "Bram launch email failed to send.",
      },
    });
  });

  it("sends both launch email variants to developer accounts for the cron test", async () => {
    const supabase = supabaseMock({
      devAccountRows: [{ user_id: userId, email: "dev@trybram.app" }],
    });
    const resend = resendMock();

    const result = await sendDevLaunchEmailTest(
      { now: new Date("2026-05-19T20:50:00.000Z") },
      { supabase: supabase.client, resend },
    );

    expect(result).toMatchObject({ status: "sent", sent: 2, failed: 0 });
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: "dev@trybram.app",
        subject: "Bram launches today — your first month is free",
      }),
    );
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: "dev@trybram.app",
        subject: "Bram launches today — you have lifetime access",
      }),
    );
  });
});
