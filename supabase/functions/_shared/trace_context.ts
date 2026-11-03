const W3C_TRACEPARENT =
  /^[0-9a-f]{2}-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$/;
const SAFE_CALLER_TRACE_ID = /^[A-Za-z0-9._:-]{1,128}$/;

/** Returns the W3C trace ID, or a safe legacy caller ID, or a fresh UUID. */
export function requestTraceId(
  req: Request,
  callerTraceId?: unknown,
  fallback: () => string = crypto.randomUUID,
): string {
  const traceparent = req.headers.get("traceparent")?.trim() ?? "";
  const match = W3C_TRACEPARENT.exec(traceparent);
  if (
    match &&
    match[1] !== "00000000000000000000000000000000" &&
    match[2] !== "0000000000000000"
  ) {
    return match[1];
  }

  if (typeof callerTraceId === "string") {
    const candidate = callerTraceId.trim();
    if (SAFE_CALLER_TRACE_ID.test(candidate)) return candidate;
  }

  return fallback();
}
