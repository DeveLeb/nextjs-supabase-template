import { createClient } from "@/supabase/utils/server";
import { InfoIcon } from "lucide-react";
import { redirect } from "next/navigation";
import { createNote, getUserNotes, deleteNote } from "../actions";
import { SubmitButton } from "@/components/submit-button";

export default async function ProtectedPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return redirect("/sign-in");
  }

  const notes = await getUserNotes(user.id);

  return (
    <div className="flex-1 w-full flex flex-col gap-12">
      <div className="w-full">
        <div className="bg-accent text-sm p-3 px-5 rounded-md text-foreground flex gap-3 items-center">
          <InfoIcon size="16" strokeWidth={2} />
          This is a protected page that you can only see as an authenticated
          user
        </div>
      </div>
      <form method="post" className="w-full flex flex-col gap-3">
        <input name="title" />
        <textarea
          name="description"
          placeholder="Enter your note"
          className="p-2 border rounded-md"
        ></textarea>
        <SubmitButton
          formAction={createNote}
          type="submit"
          className="p-2 bg-blue-500 text-white rounded-md"
        >
          Create Note
        </SubmitButton>
      </form>
      <div className="w-full flex flex-col gap-3">
        {notes?.map((note) => (
          <div
            key={note.id}
            className="p-2 border rounded-md flex justify-between items-center"
          >
            <span>{note.description}</span>
            <form method="post" className="inline">
              <input type="hidden" name="noteId" value={note.id} />
              <SubmitButton
                formAction={deleteNote}
                type="submit"
                className="p-2 bg-red-500 text-white rounded-md"
              >
                Delete
              </SubmitButton>
            </form>
          </div>
        ))}
      </div>
    </div>
  );
}
