import { createHash } from "node:crypto";

import { z } from "zod";

const tiktokEventsEndpoint =
  "https://business-api.tiktok.com/open_api/v1.3/event/track/";

const publicConfigSchema = z.object({
  accessToken: z.string().min(1),
  appId: z.string().min(1),
  tiktokAppId: z.string().min(1),
  debugMode: z.boolean(),
});

export type TikTokAppEventName = "CompleteTutorial" | "StartTrial" | "Subscribe";

export type TikTokAppEvent = {
  event: TikTokAppEventName;
  eventId: string;
  eventTime?: number;
  externalId?: string | null;
  properties?: Record<string, string | number | boolean | null | undefined>;
};

type TikTokEventsClients = {
  fetch?: typeof fetch;
};

export class TikTokEventsConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TikTokEventsConfigError";
  }
}

export class TikTokEventsAPIError extends Error {
  constructor(
    readonly status: number,
    readonly body: string,
  ) {
    super(`TikTok Events API request failed with ${status}: ${body}`);
    this.name = "TikTokEventsAPIError";
  }
}

export function tiktokAppEventsConfig() {
  if (process.env.TIKTOK_APP_EVENTS_ENABLED !== "true") {
    return { enabled: false as const };
  }

  const parsed = publicConfigSchema.safeParse({
    accessToken: process.env.TIKTOK_IOS_ACCESS_TOKEN,
    appId: process.env.TIKTOK_IOS_APP_ID,
    tiktokAppId: process.env.TIKTOK_IOS_TIKTOK_APP_ID,
    debugMode: process.env.TIKTOK_APP_EVENTS_DEBUG === "true",
  });

  if (!parsed.success) {
    return { enabled: false as const };
  }

  return {
    enabled: true as const,
    ...parsed.data,
  };
}

function serverConfig() {
  if (process.env.TIKTOK_APP_EVENTS_ENABLED !== "true") {
    return null;
  }

  const appId = process.env.TIKTOK_IOS_TIKTOK_APP_ID;
  const accessToken =
    process.env.TIKTOK_EVENTS_API_ACCESS_TOKEN ?? process.env.TIKTOK_IOS_ACCESS_TOKEN;

  if (!appId || !accessToken) {
    return null;
  }

  return { appId, accessToken };
}

function cleanProperties(
  properties: TikTokAppEvent["properties"] = {},
): Record<string, string | number | boolean> {
  return Object.fromEntries(
    Object.entries(properties).filter(
      (entry): entry is [string, string | number | boolean] =>
        entry[1] !== null && entry[1] !== undefined,
    ),
  );
}

function sha256(value: string) {
  return createHash("sha256").update(value.trim().toLowerCase()).digest("hex");
}

export async function sendTikTokAppEvent(
  event: TikTokAppEvent,
  clients: TikTokEventsClients = {},
) {
  const config = serverConfig();
  if (!config) {
    return { sent: false as const, reason: "not_configured" as const };
  }

  const fetchImpl = clients.fetch ?? fetch;
  const response = await fetchImpl(tiktokEventsEndpoint, {
    method: "POST",
    headers: {
      "Access-Token": config.accessToken,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      event_source: "app",
      event_source_id: config.appId,
      data: [
        {
          event: event.event,
          event_time: event.eventTime ?? Math.floor(Date.now() / 1000),
          event_id: event.eventId,
          user: event.externalId ? { external_id: sha256(event.externalId) } : undefined,
          properties: cleanProperties(event.properties),
        },
      ],
    }),
  });

  if (!response.ok) {
    let body = "";
    try {
      body = (await response.text()).slice(0, 500);
    } catch {
      body = "Unable to read TikTok Events API error body.";
    }
    throw new TikTokEventsAPIError(response.status, body);
  }

  return { sent: true as const };
}
