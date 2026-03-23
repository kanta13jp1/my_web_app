import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ImportedNoteDraft {
  title?: string;
  content?: string;
  source?: string;
  tags?: string[];
}

interface ImportCommitRequest {
  userId?: string;
  notes?: ImportedNoteDraft[];
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Missing authorization header.");
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      throw new Error("Unauthorized");
    }

    const body = (await req.json()) as ImportCommitRequest;
    const requestedUserId = body.userId?.trim();
    if (requestedUserId && requestedUserId !== user.id) {
      throw new Error("userId does not match the authenticated user.");
    }

    const notes = Array.isArray(body.notes) ? body.notes : [];
    if (notes.length === 0) {
      return jsonResponse({
        success: true,
        insertedCount: 0,
        importMode: "edge-function",
      });
    }

    if (notes.length > 500) {
      throw new Error("Import batches are limited to 500 notes per request.");
    }

    const rows = notes
      .map((note) => sanitizeDraft(note, user.id))
      .filter((row) => row.content.length > 0 || row.title.length > 0);

    if (rows.length === 0) {
      return jsonResponse({
        success: true,
        insertedCount: 0,
        importMode: "edge-function",
      });
    }

    const chunkSize = 50;
    let insertedCount = 0;
    for (let index = 0; index < rows.length; index += chunkSize) {
      const chunk = rows.slice(index, index + chunkSize);
      const result = await supabaseClient.from("notes").insert(chunk);
      if (result.error) {
        throw result.error;
      }
      insertedCount += chunk.length;
    }

    return jsonResponse({
      success: true,
      insertedCount,
      importMode: "edge-function",
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse(
      {
        success: false,
        error: message,
      },
      400,
    );
  }
});

function sanitizeDraft(note: ImportedNoteDraft, userId: string) {
  const rawTitle = note.title?.toString().trim() ?? "";
  const rawContent = note.content?.toString().trim() ?? "";
  const source = note.source?.toString().trim().toLowerCase() ?? "import";

  return {
    user_id: userId,
    title: rawTitle || defaultTitleForSource(source),
    content: rawContent,
    is_archived: false,
    is_pinned: false,
  };
}

function defaultTitleForSource(source: string): string {
  switch (source) {
    case "notion":
      return "Notion import";
    case "evernote":
      return "Evernote import";
    case "markdown":
      return "Markdown import";
    default:
      return "Imported note";
  }
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
