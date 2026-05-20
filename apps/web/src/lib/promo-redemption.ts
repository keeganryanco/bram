import { createClient } from "@supabase/supabase-js";
import { z } from "zod";

const PromoCodeSchema = z
  .string()
  .trim()
  .min(3)
  .max(40)
  .transform((value) => value.replace(/[\s-]/g, "").toUpperCase());

type SupabasePromoFilter = {
  eq: (column: string, value: string | boolean) => SupabasePromoFilter;
  in: (column: string, values: string[]) => SupabasePromoFilter;
  is: (column: string, value: null) => SupabasePromoFilter;
  or: (filters: string) => SupabasePromoFilter;
  order: (column: string, options?: { ascending?: boolean }) => SupabasePromoFilter;
  limit: (count: number) => Promise<{ data: Record<string, unknown>[] | null; error: unknown | null }>;
  maybeSingle: () => Promise<{ data: Record<string, unknown> | null; error: unknown | null }>;
  single: () => Promise<{ data: Record<string, unknown> | null; error: unknown | null }>;
};

type SupabasePromoClient = {
  auth: {
    getUser: (
      jwt: string,
    ) => Promise<{ data: { user: { id: string } | null }; error: unknown | null }>;
  };
  from: (table: string) => {
    select: (columns?: string) => SupabasePromoFilter;
    update: (values: Record<string, unknown>) => {
      eq: (column: string, value: string) => Promise<{ error: unknown | null }>;
    };
    upsert: (
      values: Record<string, unknown>,
      options?: { onConflict?: string; ignoreDuplicates?: boolean },
    ) => Promise<{ error: unknown | null }>;
    insert: (values: Record<string, unknown>) => Promise<{ error: unknown | null }>;
  };
};

export class PromoRedemptionError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.name = "PromoRedemptionError";
    this.status = status;
  }
}

let supabaseAdmin: SupabasePromoClient | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new PromoRedemptionError("Supabase promo environment is missing.", 503);
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as SupabasePromoClient;
  return supabaseAdmin;
}

export async function redeemPromoCodeForToken(
  accessToken: string,
  rawCode: string,
  clients: { supabase?: SupabasePromoClient } = {},
) {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const { data, error } = await supabase.auth.getUser(accessToken);
  if (error || !data.user) {
    throw new PromoRedemptionError("Unauthorized.", 401);
  }
  PromoCodeSchema.parse(rawCode);
  throw new PromoRedemptionError(
    "Use Apple's offer-code redemption flow for subscription offers.",
    410,
  );
}
