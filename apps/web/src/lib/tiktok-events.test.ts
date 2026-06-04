import { describe, expect, it, vi } from "vitest";
import { sendTikTokAppEvent, tiktokAppEventsConfig } from "./tiktok-events";

describe("tiktokAppEventsConfig", () => {
  it("stays disabled until TikTok app events are explicitly enabled", () => {
    vi.stubEnv("TIKTOK_APP_EVENTS_ENABLED", "false");

    expect(tiktokAppEventsConfig()).toEqual({ enabled: false });
    vi.unstubAllEnvs();
  });

  it("returns the iOS SDK config when all required values are present", () => {
    vi.stubEnv("TIKTOK_APP_EVENTS_ENABLED", "true");
    vi.stubEnv("TIKTOK_IOS_ACCESS_TOKEN", "sdk_token");
    vi.stubEnv("TIKTOK_IOS_APP_ID", "ios_app_id");
    vi.stubEnv("TIKTOK_IOS_TIKTOK_APP_ID", "tiktok_app_id");
    vi.stubEnv("TIKTOK_APP_EVENTS_DEBUG", "true");

    expect(tiktokAppEventsConfig()).toEqual({
      enabled: true,
      accessToken: "sdk_token",
      appId: "ios_app_id",
      tiktokAppId: "tiktok_app_id",
      debugMode: true,
    });
    vi.unstubAllEnvs();
  });
});

describe("sendTikTokAppEvent", () => {
  it("noops when server-side TikTok events are not configured", async () => {
    vi.stubEnv("TIKTOK_APP_EVENTS_ENABLED", "false");
    const fetch = vi.fn();

    await expect(
      sendTikTokAppEvent(
        {
          event: "StartTrial",
          eventId: "event_123",
          externalId: "11111111-1111-4111-8111-111111111111",
        },
        { fetch: fetch as unknown as typeof globalThis.fetch },
      ),
    ).resolves.toEqual({ sent: false, reason: "not_configured" });
    expect(fetch).not.toHaveBeenCalled();
    vi.unstubAllEnvs();
  });

  it("sends app events with a hashed external id", async () => {
    vi.stubEnv("TIKTOK_APP_EVENTS_ENABLED", "true");
    vi.stubEnv("TIKTOK_IOS_ACCESS_TOKEN", "server_token");
    vi.stubEnv("TIKTOK_IOS_TIKTOK_APP_ID", "tiktok_app_id");
    const fetch = vi.fn(async () => ({ ok: true })) as unknown as typeof globalThis.fetch;

    await sendTikTokAppEvent(
      {
        event: "Subscribe",
        eventId: "event_123",
        eventTime: 1_777_777_777,
        externalId: "11111111-1111-4111-8111-111111111111",
        properties: {
          content_id: "app.trybram.Bram.premium.year",
          content_type: "subscription",
          currency: "USD",
          value: 49.99,
        },
      },
      { fetch },
    );

    const [, request] = vi.mocked(fetch).mock.calls[0];
    const body = JSON.parse(String((request as RequestInit).body));
    expect(body).toMatchObject({
      event_source: "app",
      event_source_id: "tiktok_app_id",
      data: [
        {
          event: "Subscribe",
          event_time: 1_777_777_777,
          event_id: "event_123",
          properties: {
            content_id: "app.trybram.Bram.premium.year",
            content_type: "subscription",
            currency: "USD",
            value: 49.99,
          },
        },
      ],
    });
    expect(body.data[0].user.external_id).toMatch(/^[a-f0-9]{64}$/);
    vi.unstubAllEnvs();
  });
});
