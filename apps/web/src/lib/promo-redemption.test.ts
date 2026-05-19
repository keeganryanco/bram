import { describe, expect, it, vi } from "vitest";
import { redeemPromoCodeForToken } from "./promo-redemption";

vi.mock("./revenuecat", () => ({
  fetchAccountSnapshot: vi.fn(async () => ({
    account_tier: "FREE_PREMIUM",
    active_promo_kind: "TESTFLIGHT_1MONTH",
  })),
}));

const userId = "11111111-1111-4111-8111-111111111111";

function makeFilter(table: string) {
  const filter = {
    eq: vi.fn(() => filter),
    in: vi.fn(() => filter),
    is: vi.fn(() => filter),
    or: vi.fn(() => filter),
    order: vi.fn(() => filter),
    limit: vi.fn(async () => ({ data: [], error: null })),
    maybeSingle: vi.fn(async () => ({ data: null, error: null })),
    single: vi.fn(async () => ({
      data: table === "profiles" ? { email: "tester@trybram.app" } : null,
      error: null,
    })),
  };

  return filter;
}

function supabaseMock() {
  const inserts: { table: string; values: Record<string, unknown> }[] = [];
  const updates: { table: string; values: Record<string, unknown> }[] = [];

  return {
    client: {
      auth: {
        getUser: vi.fn(async () => ({
          data: { user: { id: userId } },
          error: null,
        })),
      },
      from: vi.fn((table: string) => ({
        select: vi.fn(() => makeFilter(table)),
        update: vi.fn((values: Record<string, unknown>) => ({
          eq: vi.fn(async () => {
            updates.push({ table, values });
            return { error: null };
          }),
        })),
        upsert: vi.fn(async () => ({ error: null })),
        insert: vi.fn(async (values: Record<string, unknown>) => {
          inserts.push({ table, values });
          return { error: null };
        }),
      })),
    },
    inserts,
    updates,
  };
}

function resendMock() {
  return {
    emails: {
      send: vi.fn(async () => ({ data: { id: "email_1" }, error: null })),
    },
  };
}

describe("redeemPromoCodeForToken", () => {
  it("sends the TestFlight welcome email after a successful TestFlight promo redemption", async () => {
    const supabase = supabaseMock();
    const resend = resendMock();

    const result = await redeemPromoCodeForToken("token", "TESTFLIGHT1MONTH", {
      supabase: supabase.client,
      resend,
    });

    expect(result).toMatchObject({ account_tier: "FREE_PREMIUM" });
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: "tester@trybram.app",
        subject: "Welcome to the Bram TestFlight",
      }),
    );
    expect(supabase.inserts).toContainEqual(
      expect.objectContaining({
        table: "account_email_events",
        values: expect.objectContaining({
          user_id: userId,
          event_key: "testflight_welcome_2026_05",
        }),
      }),
    );
  });
});
