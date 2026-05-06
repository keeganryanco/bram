import { createHash } from "crypto";

const EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi;
const PHONE_PATTERN = /\b(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)\d{3}[-.\s]?\d{4}\b/g;

export type SanitizedAIInput = {
  text: string;
  redactions: {
    emails: number;
    phoneNumbers: number;
    truncated: boolean;
  };
};

function replaceAndCount(value: string, pattern: RegExp, replacement: string) {
  let count = 0;
  const text = value.replace(pattern, () => {
    count += 1;
    return replacement;
  });

  return { text, count };
}

export function sanitizeAIInputText(
  value: string,
  maxChars: number,
): SanitizedAIInput {
  const emailResult = replaceAndCount(value, EMAIL_PATTERN, "[redacted-email]");
  const phoneResult = replaceAndCount(
    emailResult.text,
    PHONE_PATTERN,
    "[redacted-phone]",
  );
  const normalized = phoneResult.text.replace(/\s+\n/g, "\n").trim();
  const truncated = normalized.length > maxChars;

  return {
    text: truncated ? normalized.slice(0, maxChars) : normalized,
    redactions: {
      emails: emailResult.count,
      phoneNumbers: phoneResult.count,
      truncated,
    },
  };
}

export function createPseudonymousUserId(userId: string, salt: string) {
  return createHash("sha256")
    .update(`${salt}:${userId}`)
    .digest("hex")
    .slice(0, 32);
}
