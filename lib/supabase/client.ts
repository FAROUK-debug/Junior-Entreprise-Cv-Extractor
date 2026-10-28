// The Supabase client for code that runs in the browser ("use client" components).
// It only has the public anon key, so the database rules (RLS) decide what it can see.
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
