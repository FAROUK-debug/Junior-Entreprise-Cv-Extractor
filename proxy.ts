// Next.js 16 "proxy" (it was called middleware before): runs before every page request.
// For now it only keeps the Supabase login fresh. Role checks per area come in S2-01.
import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";

export async function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  // Every path except static files and images, which don't need a session.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
