import { describe, expect, it, vi } from "vitest";
import {
  normalizePasswordResetEmail,
  sendPasswordResetEmail,
} from "./password-reset";

function supabaseMock(actionLink = "https://trybram.app/reset-password#token") {
  return {
    auth: {
      admin: {
        generateLink: vi.fn(async () => ({
          data: {
            properties: {
              action_link: actionLink,
            },
          },
          error: null,
        })),
      },
    },
  };
}

function resendMock() {
  return {
    emails: {
      send: vi.fn(async () => ({ data: { id: "email_123" }, error: null })),
    },
  };
}

describe("normalizePasswordResetEmail", () => {
  it("trims and lowercases valid emails", () => {
    const result = normalizePasswordResetEmail("  Keegan@TryBram.App ");

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data).toBe("keegan@trybram.app");
    }
  });
});

describe("sendPasswordResetEmail", () => {
  it("generates a Supabase recovery link and sends it with Resend", async () => {
    const supabase = supabaseMock();
    const resend = resendMock();

    await sendPasswordResetEmail("lift@trybram.app", { supabase, resend });

    expect(supabase.auth.admin.generateLink).toHaveBeenCalledWith({
      type: "recovery",
      email: "lift@trybram.app",
      options: {
        redirectTo: "https://trybram.app/reset-password",
      },
    });
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        from: "Keegan at Bram <keegan@trybram.app>",
        to: "lift@trybram.app",
        subject: "Reset your Bram password",
        text: expect.stringContaining("https://trybram.app/reset-password"),
        html: expect.stringContaining("Reset password"),
      }),
    );
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
      sendPasswordResetEmail("lift@trybram.app", { supabase, resend }),
    ).rejects.toThrow("Bram password reset email failed to send.");
  });
});
