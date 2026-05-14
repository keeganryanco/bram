import { createClient } from "@supabase/supabase-js";

type SupabaseAccountDeletionClient = {
  auth: {
    getUser: (
      jwt: string,
    ) => Promise<{ data: { user: { id: string } | null }; error: unknown | null }>;
    admin: {
      deleteUser: (userId: string) => Promise<{ data: unknown; error: unknown | null }>;
    };
  };
};

type AccountDeletionClients = {
  supabase?: SupabaseAccountDeletionClient;
};

export class AccountDeletionConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AccountDeletionConfigError";
  }
}

let supabaseAdmin: SupabaseAccountDeletionClient | null = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) {
    return supabaseAdmin;
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new AccountDeletionConfigError("Supabase account deletion is missing.");
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }) as unknown as SupabaseAccountDeletionClient;

  return supabaseAdmin;
}

export async function deleteAccountForToken(
  accessToken: string,
  clients: AccountDeletionClients = {},
) {
  const supabase = clients.supabase ?? getSupabaseAdmin();
  const { data, error } = await supabase.auth.getUser(accessToken);

  if (error || !data.user) {
    throw new Error("Invalid Supabase session.");
  }

  const result = await supabase.auth.admin.deleteUser(data.user.id);
  if (result.error) {
    throw result.error;
  }

  return { userId: data.user.id };
}
