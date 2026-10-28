// Placeholder so everyone sees where their pages go. Replaced by the real page in its task.
// Texts always come from messages/ (en.json + fr.json), never typed in the page. S1-14 adds the language switch.
import en from "@/messages/en.json";

export default function AdminPage() {
  return (
    <main className="flex flex-1 items-center justify-center p-8">
      <p className="text-lg">{en.placeholder.admin}</p>
    </main>
  );
}
