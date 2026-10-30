// The bar at the bottom of every page (added once in app/layout.tsx).
import Link from "next/link";
import en from "@/messages/en.json";

export function SiteFooter() {
  return (
    <footer className="border-t bg-card">
      <div className="mx-auto flex w-full max-w-5xl flex-col gap-2 px-4 py-6 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <p>
          <span className="font-medium text-foreground">{en.site.clubName}</span> · {en.site.footerNote}
        </p>
        {/* The privacy notice page comes with its own task; the link is ready. */}
        <Link href="/privacy" className="underline-offset-4 hover:text-foreground hover:underline">
          {en.site.privacy}
        </Link>
      </div>
    </footer>
  );
}
