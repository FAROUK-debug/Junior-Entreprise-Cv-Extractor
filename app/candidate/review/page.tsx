import { Suspense } from "react";
import { getCurrentUser } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ProfileSchema } from "@/lib/profile/schema.gen";
import { ProfileReviewForm } from "@/components/profile/profile-review-form";
import en from "@/messages/en.json";

export default function ReviewPage() {
  return <main className="mx-auto w-full max-w-4xl p-4 sm:p-8">
    <Suspense fallback={<p role="status">{en.review.loading}</p>}><ReviewDraft /></Suspense>
  </main>;
}

async function ReviewDraft() {
  const copy = en.review;
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) return <p role="alert">{copy.unavailable}</p>;
  const user = await getCurrentUser();
  if (!user || user.role !== "candidate" || !user.emailConfirmed) return <p role="alert">{copy.unauthorized}</p>;
  const client = await createClient();
  const [{ data: draft, error }, { data: profile, error: profileError }] = await Promise.all([
    client.from("profile_drafts").select("data, updated_at").eq("user_id", user.id).maybeSingle(),
    client.from("profiles").select("looking_for").eq("user_id", user.id).maybeSingle(),
  ]);
  if (error || profileError) return <p role="alert">{copy.failedLoad}</p>;
  if (!draft) return <p role="status">{copy.noDraft}</p>;
  const parsed = ProfileSchema.safeParse({ ...draft.data, looking_for: profile?.looking_for ?? null });
  if (!parsed.success) return <p role="alert">{copy.invalidDraft}</p>;
  return <ProfileReviewForm initialValues={{ ...parsed.data, looking_for: profile?.looking_for ?? null }} updatedAt={draft.updated_at} />;
}
