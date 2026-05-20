import { describe, expect, it, vi } from "vitest";
import { redeemPromoCodeForToken } from "./promo-redemption";

function supabaseMock() {
  return {
    auth: {
      getUser: vi.fn(async () => ({
        data: { user: { id: "11111111-1111-4111-8111-111111111111" } },
        error: null,
      })),
    },
    from: vi.fn(),
  };
}

describe("redeemPromoCodeForToken", () => {
  it("rejects Bram-owned public promo codes in the reviewed app path", async () => {
    await expect(
      redeemPromoCodeForToken("token", "TESTFLIGHT1MONTH", {
        supabase: supabaseMock(),
      }),
    ).rejects.toMatchObject({
      status: 410,
      message: "Use Apple's offer-code redemption flow for subscription offers.",
    });
  });
});
