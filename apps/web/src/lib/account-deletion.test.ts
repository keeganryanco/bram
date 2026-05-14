import { describe, expect, it, vi } from "vitest";
import { deleteAccountForToken } from "./account-deletion";

function supabaseMock(authUser: string | null = "11111111-1111-4111-8111-111111111111") {
  return {
    auth: {
      getUser: vi.fn(async () =>
        authUser
          ? { data: { user: { id: authUser } }, error: null }
          : { data: { user: null }, error: { message: "bad token" } },
      ),
      admin: {
        deleteUser: vi.fn(async () => ({ data: {}, error: null })),
      },
    },
  };
}

describe("deleteAccountForToken", () => {
  it("rejects an invalid Supabase session", async () => {
    const supabase = supabaseMock(null);

    await expect(
      deleteAccountForToken("bad-token", { supabase }),
    ).rejects.toThrow("Invalid Supabase session.");

    expect(supabase.auth.admin.deleteUser).not.toHaveBeenCalled();
  });

  it("deletes only the authenticated Supabase user", async () => {
    const userId = "11111111-1111-4111-8111-111111111111";
    const supabase = supabaseMock(userId);

    await deleteAccountForToken("good-token", { supabase });

    expect(supabase.auth.getUser).toHaveBeenCalledWith("good-token");
    expect(supabase.auth.admin.deleteUser).toHaveBeenCalledWith(userId);
  });
});
