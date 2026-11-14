import { auditArgumentMetadata } from "./mcp_audit_metadata.ts";

function verify(value: unknown, type: string): void {
  const actual = JSON.stringify(auditArgumentMetadata(value));
  const expected = JSON.stringify({
    policy: "metadata_only_v1",
    redacted: true,
    input_type: type,
  });
  if (actual !== expected) throw new Error("unexpected audit metadata");
}

Deno.test("audit excludes nested secrets, PII and unknown free text", () => {
  verify({ token: "synthetic-token", nested: [{ email: "example@example.invalid" }],
    note: "synthetic-secret-in-ordinary-text" }, "object");
});
Deno.test("audit excludes raw string and array contents", () => {
  verify("synthetic-credential", "string");
  verify(["synthetic-password"], "object");
});
Deno.test("audit handles null, undefined, bigint and symbols", () => {
  verify(null, "null");
  verify(undefined, "undefined");
  verify(1n, "bigint");
  verify(Symbol("synthetic-secret"), "symbol");
});
Deno.test("audit never invokes getters, toJSON or toString", () => {
  const fail = () => { throw new Error("caller code executed"); };
  verify({ get token() { return fail(); }, toJSON: fail, toString: fail }, "object");
});
Deno.test("audit has bounded output for cyclic and oversized inputs", () => {
  const cyclic: Record<string, unknown> = {};
  cyclic.self = cyclic;
  verify(cyclic, "object");
  verify("x".repeat(100000), "string");
  if (JSON.stringify(auditArgumentMetadata(cyclic)).length > 100) {
    throw new Error("unbounded metadata");
  }
});
Deno.test("audit does not inspect revoked proxies or execute functions", () => {
  const proxy = Proxy.revocable({}, {});
  proxy.revoke();
  verify(proxy.proxy, "object");
  verify(() => { throw new Error("must not run"); }, "function");
});
