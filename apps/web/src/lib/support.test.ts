import { describe, expect, it, vi } from "vitest";
import {
  createSupportRequestForToken,
  recordAppErrorForToken,
  SupportRequestError,
} from "./support";

function makeSupabase(overrides: { userError?: boolean; insertError?: boolean } = {}) {
  const updates: Record<string, unknown>[] = [];
  const inserts: Record<string, unknown>[] = [];
  return {
    client: {
      auth: {
        getUser: vi.fn(async () => ({
          data: {
            user: overrides.userError
              ? null
              : { id: "11111111-1111-4111-8111-111111111111", email: "user@example.com" },
          },
          error: overrides.userError ? new Error("nope") : null,
        })),
      },
      from: vi.fn((table: string) => ({
        select: () => ({
          eq: () => ({
            maybeSingle: async () => ({
              data: table === "profiles" ? { display_name: "Keegan" } : null,
              error: null,
            }),
          }),
        }),
        insert: (values: Record<string, unknown>) => {
          inserts.push({ table, ...values });
          return {
            select: () => ({
              single: async () => ({
                data: overrides.insertError ? null : { id: "22222222-2222-4222-8222-222222222222" },
                error: overrides.insertError ? new Error("insert failed") : null,
              }),
            }),
          };
        },
        update: (values: Record<string, unknown>) => ({
          eq: async () => {
            updates.push({ table, ...values });
            return { error: null };
          },
        }),
      })),
    },
    inserts,
    updates,
  };
}

describe("support intake", () => {
  it("rejects invalid Supabase sessions", async () => {
    const { client } = makeSupabase({ userError: true });

    await expect(
      createSupportRequestForToken(
        "bad-token",
        { category: "BUG", message: "The app crashed while opening settings." },
        { supabase: client, linearIssueCreator: async () => null },
      ),
    ).rejects.toMatchObject({ status: 401 });
  });

  it("creates a support request and mirrors Linear metadata when configured", async () => {
    const { client, inserts, updates } = makeSupabase();

    const result = await createSupportRequestForToken(
      "token",
      {
        category: "WORKOUT_DATA",
        message: "My workout note did not sync after saving.",
        source: "settings_support",
        diagnostics: { appVersion: "0.1.0", osVersion: "iOS 26.0" },
      },
      {
        supabase: client,
        linearIssueCreator: async () => ({
          id: "linear-id",
          identifier: "BRA-99",
          url: "https://linear.app/bram/issue/BRA-99",
        }),
      },
    );

    expect(result.linearIssue?.identifier).toBe("BRA-99");
    expect(inserts[0]).toMatchObject({
      table: "support_requests",
      user_id: "11111111-1111-4111-8111-111111111111",
      category: "WORKOUT_DATA",
      contact_display_name: "Keegan",
      source: "settings_support",
      app_version: "0.1.0",
    });
    expect(updates[0]).toMatchObject({
      table: "support_requests",
      linear_issue_id: "BRA-99",
    });
  });

  it("records app errors without raw note content", async () => {
    const { client, inserts } = makeSupabase();

    await recordAppErrorForToken(
      "token",
      {
        severity: "ERROR",
        source: "home",
        eventName: "note_load_failed",
        message: "Could not load note.",
        metadata: { dayOffset: "0" },
      },
      { supabase: client },
    );

    expect(inserts[0]).toMatchObject({
      table: "app_error_reports",
      event_name: "note_load_failed",
      metadata: { dayOffset: "0" },
    });
    expect(JSON.stringify(inserts[0])).not.toContain("bench");
  });

  it("surfaces insert failures", async () => {
    const { client } = makeSupabase({ insertError: true });

    await expect(
      recordAppErrorForToken(
        "token",
        { severity: "ERROR", source: "test", eventName: "failed" },
        { supabase: client },
      ),
    ).rejects.toBeInstanceOf(SupportRequestError);
  });
});
