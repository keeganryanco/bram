import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createLinearIssue, type LinearIssueResult } from "./linear";

const SupportCategorySchema = z.enum([
  "BUG",
  "ACCOUNT",
  "BILLING",
  "WORKOUT_DATA",
  "FEEDBACK",
  "OTHER",
]);

const ClientDiagnosticsSchema = z
  .object({
    appVersion: z.string().max(40).optional(),
    buildNumber: z.string().max(40).optional(),
    osVersion: z.string().max(80).optional(),
    deviceModel: z.string().max(120).optional(),
    locale: z.string().max(40).optional(),
    timezone: z.string().max(80).optional(),
    screen: z.string().max(80).optional(),
  })
  .passthrough();

export const SupportRequestInputSchema = z.object({
  category: SupportCategorySchema,
  message: z.string().trim().min(1).max(4000),
  contactEmail: z.string().email().optional(),
  diagnostics: ClientDiagnosticsSchema.optional(),
  source: z.string().max(80).optional(),
});

export const AppErrorReportInputSchema = z.object({
  severity: z.enum(["INFO", "WARNING", "ERROR", "FATAL"]).default("ERROR"),
  source: z.string().min(1).max(80),
  eventName: z.string().min(1).max(120),
  message: z.string().max(1000).optional(),
  errorCode: z.string().max(120).optional(),
  diagnostics: ClientDiagnosticsSchema.optional(),
  metadata: z.record(z.string(), z.string().max(240)).optional(),
});

export type SupportRequestInput = z.infer<typeof SupportRequestInputSchema>;
export type AppErrorReportInput = z.infer<typeof AppErrorReportInputSchema>;

type SupabaseSupportClient = {
  auth: {
    getUser: (token: string) => Promise<{
      data: { user: { id: string; email?: string } | null };
      error: unknown | null;
    }>;
  };
  from: (table: string) => {
    insert: (values: Record<string, unknown>) => {
      select: (columns?: string) => {
        single: () => Promise<{ data: unknown; error: unknown | null }>;
      };
    };
    update: (values: Record<string, unknown>) => {
      eq: (column: string, value: string) => Promise<{ error: unknown | null }>;
    };
    select?: (columns?: string) => {
      eq: (column: string, value: string) => {
        maybeSingle: () => Promise<{ data: unknown; error: unknown | null }>;
      };
    };
  };
};

export class SupportConfigError extends Error {
  constructor(message = "Support intake is not configured.") {
    super(message);
    this.name = "SupportConfigError";
  }
}

export class SupportRequestError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.name = "SupportRequestError";
    this.status = status;
  }
}

let supabaseAdmin: SupabaseSupportClient | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new SupportConfigError();
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as SupabaseSupportClient;
  return supabaseAdmin;
}

export function bearerTokenFromRequest(request: Request) {
  const authorization = request.headers.get("authorization");
  return authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : null;
}

async function requireUser(supabase: SupabaseSupportClient, accessToken: string) {
  const { data, error } = await supabase.auth.getUser(accessToken);
  if (error || !data.user) {
    throw new SupportRequestError("Unauthorized.", 401);
  }
  return data.user;
}

async function profileDisplayName(supabase: SupabaseSupportClient, userId: string) {
  try {
    const query = supabase.from("profiles").select?.("display_name");
    if (!query) {
      return null;
    }
    const { data, error } = await query.eq("id", userId).maybeSingle();
    if (error || !data || typeof data !== "object" || !("display_name" in data)) {
      return null;
    }
    const profile = data as { display_name?: unknown };
    return typeof profile.display_name === "string" ? profile.display_name : null;
  } catch {
    return null;
  }
}

function diagnosticsColumns(input: { diagnostics?: Record<string, unknown> }) {
  return {
    app_version:
      typeof input.diagnostics?.appVersion === "string"
        ? input.diagnostics.appVersion
        : null,
    build_number:
      typeof input.diagnostics?.buildNumber === "string"
        ? input.diagnostics.buildNumber
        : null,
    os_version:
      typeof input.diagnostics?.osVersion === "string"
        ? input.diagnostics.osVersion
        : null,
    device_model:
      typeof input.diagnostics?.deviceModel === "string"
        ? input.diagnostics.deviceModel
        : null,
  };
}

function linearDescription(
  input: SupportRequestInput,
  user: { id: string; email?: string },
  displayName: string | null,
) {
  const lines = [
    `Category: ${input.category}`,
    input.source ? `Source: ${input.source}` : null,
    `Supabase user: ${user.id}`,
    displayName ? `Name: ${displayName}` : null,
    input.contactEmail || user.email ? `Contact: ${input.contactEmail ?? user.email}` : null,
    "",
    input.message,
  ].filter((line): line is string => line !== null);

  if (input.diagnostics) {
    lines.push("", "Diagnostics:", "```json", JSON.stringify(input.diagnostics, null, 2), "```");
  }

  return lines.join("\n");
}

export async function createSupportRequestForToken(
  accessToken: string,
  input: SupportRequestInput,
  clients: {
    supabase?: SupabaseSupportClient;
    linearIssueCreator?: typeof createLinearIssue;
  } = {},
) {
  const request = SupportRequestInputSchema.parse(input);
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const user = await requireUser(supabase, accessToken);
  const displayName = await profileDisplayName(supabase, user.id);

  const { data, error } = await supabase
    .from("support_requests")
    .insert({
      user_id: user.id,
      category: request.category,
      message: request.message,
      contact_email: request.contactEmail ?? user.email ?? null,
      contact_display_name: displayName,
      source: request.source ?? null,
      diagnostics: request.diagnostics ?? {},
      ...diagnosticsColumns(request),
    })
    .select("id")
    .single();

  if (error || !data || typeof data !== "object" || !("id" in data)) {
    throw new SupportRequestError("Could not create support request.");
  }

  let linearIssue: LinearIssueResult | null = null;
  try {
    linearIssue = await (clients.linearIssueCreator ?? createLinearIssue)({
      title: `[${request.category}] Bram support request`,
      description: linearDescription(request, user, displayName),
    });
  } catch (error) {
    console.error("linear_support_issue_failed", error);
  }

  if (linearIssue) {
    await supabase
      .from("support_requests")
      .update({
        linear_issue_id: linearIssue.identifier,
        linear_issue_url: linearIssue.url,
      })
      .eq("id", String(data.id));
  }

  return {
    id: String(data.id),
    linearIssue,
  };
}

export async function recordAppErrorForToken(
  accessToken: string,
  input: AppErrorReportInput,
  clients: { supabase?: SupabaseSupportClient } = {},
) {
  const report = AppErrorReportInputSchema.parse(input);
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const user = await requireUser(supabase, accessToken);

  const { data, error } = await supabase
    .from("app_error_reports")
    .insert({
      user_id: user.id,
      severity: report.severity,
      source: report.source,
      event_name: report.eventName,
      message: report.message ?? null,
      error_code: report.errorCode ?? null,
      diagnostics: report.diagnostics ?? {},
      metadata: report.metadata ?? {},
      ...diagnosticsColumns(report),
    })
    .select("id")
    .single();

  if (error || !data || typeof data !== "object" || !("id" in data)) {
    throw new SupportRequestError("Could not record app error.");
  }

  return { id: String(data.id) };
}
