import { describe, expect, it, vi } from "vitest";
import { joinWaitlist, normalizeEmail } from "./waitlist";

function supabaseMock(error: { code?: string; message?: string } | null = null) {
  const insert = vi.fn(async () => ({ error }));
  const eq = vi.fn(async () => ({ error: null }));
  const update = vi.fn(() => ({ eq }));

  return {
    from: vi.fn(() => ({
      insert,
      update,
    })),
    insert,
    update,
    eq,
  };
}

function resendMock() {
  return {
    emails: {
      send: vi.fn(async () => ({ data: { id: "email_123" }, error: null })),
    },
  };
}

describe("normalizeEmail", () => {
  it("trims and lowercases valid emails", () => {
    const result = normalizeEmail("  Keegan@TryBram.App ");

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data).toBe("keegan@trybram.app");
    }
  });

  it("rejects invalid emails", () => {
    expect(normalizeEmail("not an email").success).toBe(false);
  });
});

describe("joinWaitlist", () => {
  it("saves and sends welcome email for a new signup", async () => {
    const supabase = supabaseMock();
    const resend = resendMock();

    const result = await joinWaitlist(
      { email: "lift@trybram.app", source: "test" },
      { supabase, resend },
    );

    expect(result.status).toBe("created");
    expect(supabase.from).toHaveBeenCalledWith("waitlist_signups");
    expect(supabase.insert).toHaveBeenCalledWith(
      expect.objectContaining({
        email: "lift@trybram.app",
        founder_discount_eligible: true,
        source: "test",
      }),
    );
    expect(resend.emails.send).toHaveBeenCalledTimes(1);
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        from: "Keegan at Bram <keegan@trybram.app>",
        subject: "You are on the Bram waitlist",
        text: expect.stringContaining("special surprise"),
        html: expect.stringContaining("Founder of Bram"),
      }),
    );
    expect(supabase.update).toHaveBeenCalledWith(
      expect.objectContaining({
        welcome_email_sent_at: expect.any(String),
      }),
    );
    expect(supabase.eq).toHaveBeenCalledWith("email", "lift@trybram.app");
  });

  it("returns duplicate without sending another welcome email", async () => {
    const supabase = supabaseMock({ code: "23505", message: "duplicate" });
    const resend = resendMock();

    const result = await joinWaitlist(
      { email: "lift@trybram.app" },
      { supabase, resend },
    );

    expect(result.status).toBe("duplicate");
    expect(resend.emails.send).not.toHaveBeenCalled();
  });

  it("fails when Resend returns an email send error", async () => {
    const supabase = supabaseMock();
    const resend = {
      emails: {
        send: vi.fn(async () => ({
          data: null,
          error: { message: "domain is not verified" },
        })),
      },
    };

    await expect(
      joinWaitlist({ email: "lift@trybram.app" }, { supabase, resend }),
    ).rejects.toThrow("Bram welcome email failed to send.");
  });
});
