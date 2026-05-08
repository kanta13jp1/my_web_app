import { Client } from "https://deno.land/x/postgres@v0.19.3/mod.ts";

const databaseUrl = Deno.env.get("DATABASE_URL");
if (!databaseUrl) {
  throw new Error("DATABASE_URL is required");
}

const port = Number(Deno.env.get("PORT") ?? "8787");
const allowedTables = new Set(["profiles", "wbs_tasks", "ai_circuit_breaker"]);

const client = new Client(databaseUrl);
await client.connect();

Deno.serve({ hostname: "127.0.0.1", port }, async (request: Request) => {
  const url = new URL(request.url);
  if (url.pathname !== "/smoke") {
    return Response.json({ status: "not_found" }, { status: 404 });
  }

  const table = url.searchParams.get("table") ?? "wbs_tasks";
  if (!allowedTables.has(table)) {
    return Response.json({ status: "bad_table" }, { status: 400 });
  }

  const rows = await client.queryObject<{ count: number }>(
    `select count(*)::int as count from ${table}`,
  );
  return Response.json({
    status: "ok",
    table,
    count: rows.rows[0].count,
  });
});
