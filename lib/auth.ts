// Who is logged in, and as what. Use this everywhere instead of reading the session yourself.
import { createClient } from "@/lib/supabase/server";

export type Role = "candidate" | "company" | "admin";

export async function getCurrentUser() {
  const supabase = await createClient();
  // getUser() asks Supabase Auth to confirm the session, so a forged cookie is refused.
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return null;
  // The role lives in app_metadata, which only the server can set. Never user_metadata:
  // users can edit that themselves.
  const role = data.user.app_metadata?.role as Role | undefined;
  return {
    id: data.user.id,
    email: data.user.email ?? "",
    role: role ?? null,
    // False until the candidate clicks the link in the confirmation email.
    emailConfirmed: Boolean(data.user.email_confirmed_at),
  };
}
