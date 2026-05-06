import { describe, expect, it, vi } from "vitest";
import { joinWaitlist, normalizeEmail } from "./waitlist";

function supabaseMock(error: { code?: string; message?: string } | null = null) {
  return {
    from: vi.fn(() => ({
      insert: vi.fn(async () => ({ error })),
    })),
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
    expect(resend.emails.send).toHaveBeenCalledTimes(1);
  });

  it("treats duplicate emails as a successful non-enumerating response", async () => {
    const supabase = supabaseMock({ code: "23505", message: "duplicate" });
    const resend = resendMock();

    const result = await joinWaitlist(
      { email: "lift@trybram.app" },
      { supabase, resend },
    );

    expect(result.status).toBe("duplicate");
    expect(resend.emails.send).not.toHaveBeenCalled();
  });
});
