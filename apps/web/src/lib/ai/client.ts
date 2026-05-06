import OpenAI from "openai";
import {
  assertBramAIReady,
  type BramAIConfig,
  getBramAIConfig,
} from "./config";
import type { BramAIResponseRequest } from "./requests";

let openAIClient: OpenAI | null = null;

export function getOpenAIClient(config: BramAIConfig = getBramAIConfig()) {
  assertBramAIReady(config);

  if (openAIClient) {
    return openAIClient;
  }

  openAIClient = new OpenAI({
    apiKey: config.apiKey,
    timeout: config.requestTimeoutMs,
  });

  return openAIClient;
}

export async function createBramAIResponse(
  request: BramAIResponseRequest,
  client = getOpenAIClient(),
) {
  return client.responses.create(
    request as Parameters<typeof client.responses.create>[0],
  );
}
