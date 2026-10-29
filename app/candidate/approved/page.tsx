// S1-32 · "Profile approved": the candidate's QR code, their business card at the fair.
// The QR code holds only the profile URL with the random public_id, never a name or an email.
// It reads the login cookie, so it sits inside <Suspense> (Next.js 16, see README).
import { Suspense } from "react";
import { getCurrentUser } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { profileUrl, qrFileName, qrPng, QR_SIZE } from "@/lib/profile/qr";
import { buttonVariants } from "@/components/ui/button";
import en from "@/messages/en.json";

const copy = en.approved;

export default function ApprovedPage() {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col items-center justify-center gap-6 p-6 text-center">
      <Suspense fallback={<p role="status">{copy.loading}</p>}>
        <ApprovedProfile />
      </Suspense>
    </main>
  );
}

async function ApprovedProfile() {
  const user = await getCurrentUser();
  if (!user || user.role !== "candidate") return <p role="alert">{copy.unauthorized}</p>;

  const supabase = await createClient();
  const { data: profile } = await supabase
    .from("profiles")
    .select("status, public_id, data")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!profile || profile.status !== "approved") {
    return (
      <>
        <p role="status">{copy.notApproved}</p>
        <a className={buttonVariants({ variant: "outline" })} href="/candidate/review">{copy.toReview}</a>
      </>
    );
  }
  if (!process.env.APP_URL) return <p role="alert">{copy.unavailable}</p>;

  const png = await qrPng(profileUrl(process.env.APP_URL, profile.public_id));
  const src = `data:image/png;base64,${png.toString("base64")}`;
  return (
    <>
      <h1 className="text-2xl font-semibold">{copy.title}</h1>
      <p>{copy.explain}</p>
      {/* A data: URL, so there is no public image route to guess; next/image doesn't apply. */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} width={QR_SIZE} height={QR_SIZE} alt={copy.qrAlt} className="h-auto w-full max-w-xs rounded-lg border" />
      <a className={buttonVariants()} href={src} download={qrFileName(profile.data?.basics?.name)}>
        {copy.download}
      </a>
    </>
  );
}
