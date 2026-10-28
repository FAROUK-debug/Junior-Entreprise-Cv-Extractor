// Shows who is logged in. Handy while building the login pages (S1-26); proves S1-10 works.
// Anything that reads the login cookie must sit inside <Suspense>, or the build fails
// (Next.js 16 Cache Components: node_modules/next/dist/docs/01-app/02-guides/authentication-with-cache-components.md).
import { Suspense } from "react";
import { getCurrentUser } from "@/lib/auth";
import en from "@/messages/en.json";

export default function WhoAmIPage() {
  return (
    <main className="flex flex-1 items-center justify-center p-8">
      <Suspense fallback={<p className="text-lg">{en.whoami.loading}</p>}>
        <WhoAmI />
      </Suspense>
    </main>
  );
}

async function WhoAmI() {
  const user = await getCurrentUser();
  return (
    <p className="text-lg">
      {user ? `${en.whoami.loggedInAs} ${user.email} (${user.role ?? en.whoami.noRole})` : en.whoami.notLoggedIn}
    </p>
  );
}
