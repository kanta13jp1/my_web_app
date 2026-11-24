// CI-only function transport. Uses synthetic users; production authenticates in tools-hub/index.ts.
import {
  handleReading,
  ReadingError,
} from "../../supabase/functions/tools-hub/reading.ts";
import { readingTestClient } from "../../supabase/functions/tools-hub/reading_test_client.ts";

const admin = await readingTestClient();
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization,apikey,content-type,x-client-info",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
};
let failed = false;
Deno.serve({ hostname: "127.0.0.1", port: 7359 }, async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method === "GET") return new Response("ready", { headers: cors });
  try {
    const body = await req.json();
    if (body.action === "fixture.reset") {
      const { error } = await admin.from("hub_data").delete().eq(
        "metadata->>user_id",
        "33333333-3333-4333-8333-333333333333",
      );
      if (error) throw error;
      failed = false;
      return Response.json({ success: true }, { headers: cors });
    }
    if (
      body.action === "reading.save" &&
      body.cycles?.some((c: { entries: { impression: string }[] }) =>
        c.entries.some((e) => e.impression === "失敗して再試行")
      ) && !failed
    ) {
      failed = true;
      throw new ReadingError(
        503,
        "保存できませんでした。入力を保持しています。再試行してください",
      );
    }
    const data = await handleReading(
      admin,
      "33333333-3333-4333-8333-333333333333",
      String(body.action),
      body,
    );
    return Response.json(data, { headers: cors });
  } catch (error) {
    return Response.json({
      error: error instanceof Error ? error.message : String(error),
    }, {
      headers: cors,
      status: error instanceof ReadingError ? error.status : 500,
    });
  }
});
