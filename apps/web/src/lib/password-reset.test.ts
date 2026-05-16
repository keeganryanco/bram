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
              hashed_token: "hashed-recovery-token",
              verification_type: "recovery",
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
        redirectTo: "https://www.trybram.app/reset-password",
      },
    });
    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        from: "Keegan at Bram <keegan@trybram.app>",
        to: "lift@trybram.app",
        subject: "Reset your Bram password",
        text: expect.stringContaining(
          "https://www.trybram.app/reset-password?token_hash=hashed-recovery-token&type=recovery",
        ),
        html: expect.stringContaining("Reset password"),
      }),
    );
  });

  it("falls back to the Supabase action link if a token hash is missing", async () => {
    const supabase = {
      auth: {
        admin: {
          generateLink: vi.fn(async () => ({
            data: {
              properties: {
                action_link: "https://njotbjmpcostgktjjihv.supabase.co/auth/v1/verify?token=abc",
                hashed_token: null,
                verification_type: "recovery",
              },
            },
            error: null,
          })),
        },
      },
    };
    const resend = resendMock();

    await sendPasswordResetEmail("lift@trybram.app", { supabase, resend });

    expect(resend.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        text: expect.stringContaining(
          "https://njotbjmpcostgktjjihv.supabase.co/auth/v1/verify?token=abc",
        ),
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
