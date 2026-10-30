// The bar at the top of every page (added once in app/layout.tsx).
// The user menu reads the login cookie, so it sits inside <Suspense> (CLAUDE.md rule 11).
import Link from "next/link";
import { Suspense } from "react";
import { getCurrentUser } from "@/lib/auth";
import en from "@/messages/en.json";
import { UserMenu } from "./user-menu";

export function SiteHeader() {
  return (
    <header className="border-b bg-card">
      <div className="mx-auto flex h-14 w-full max-w-5xl items-center gap-4 px-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2 font-heading font-semibold" aria-label={en.site.home}>
          <span className="flex size-8 items-center justify-center rounded-lg bg-primary text-sm text-primary-foreground">
            JE
          </span>
          <span className="hidden sm:inline">{en.site.appName}</span>
        </Link>
        <div className="ml-auto flex items-center gap-2">
          {/* The language switch goes here (S1-14). */}
          <div data-slot="language-switch" />
          <Suspense fallback={null}>
            <CurrentUserMenu />
          </Suspense>
        </div>
      </div>
    </header>
  );
}

async function CurrentUserMenu() {
  const user = await getCurrentUser();
  if (!user) return null;
  return <UserMenu email={user.email} role={user.role} />;
}
