/**
 * Supabase Edge Functions shared sensitive-data log masking utilities (#2732).
 */

export const MASK_PLACEHOLDER = "***";

export const DEFAULT_SENSITIVE_LOG_KEYS: ReadonlySet<string> = new Set([
  "password",
  "passwd",
  "passphrase",
  "pwd",
  "secret",
  "token",
  "access_token",
  "refresh_token",
  "id_token",
  "api_key",
  "apikey",
  "authorization",
  "cookie",
  "set_cookie",
  "service_role",
  "service_role_key",
  "private_key",
  "client_secret",
  "bearer",
  "pin",
  "email",
  "phone",
  "phone_number",
  "tel",
  "address",
  "ssn",
  "my_number",
  "credit_card",
  "card_number",
  "cvv",
  "bank_account",
  "account_number",
]);

const SENSITIVE_KEY_SUFFIXES: readonly string[] = [
  "_password",
  "_passwd",
  "_passphrase",
  "_secret",
  "_token",
  "_api_key",
  "_apikey",
  "_private_key",
  "_service_role",
  "_service_role_key",
  "_cookie",
  "_credit_card",
  "_card_number",
  "_account_number",
  "_phone",
  "_phone_number",
  "_email",
  "_cvv",
  "_ssn",
  "_my_number",
];

function normalizeKey(key: string): string {
  return key
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/[-.\s]+/g, "_")
    .toLowerCase()
    .replace(/^_+|_+$/g, "");
}

export function isSensitiveLogKey(
  key: string,
  extraKeys?: ReadonlySet<string> | readonly string[],
): boolean {
  const normalized = normalizeKey(key);
  if (normalized === "") {
    return false;
  }
  if (DEFAULT_SENSITIVE_LOG_KEYS.has(normalized)) {
    return true;
  }
  if (extraKeys) {
    for (const extra of extraKeys) {
      if (normalizeKey(extra) === normalized) {
        return true;
      }
    }
  }
  return SENSITIVE_KEY_SUFFIXES.some((suffix) => normalized.endsWith(suffix));
}

export function maskLogString(
  input: string,
  extraKeys?: ReadonlySet<string> | readonly string[],
): string {
  if (!input) {
    return input;
  }
  let result = input.replace(
    /\b(Bearer|Basic)\s+[A-Za-z0-9\-._~+/]+=*/gi,
    (_full, scheme: string) => `${scheme} ${MASK_PLACEHOLDER}`,
  );
  result = result.replace(
    /\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\b/g,
    MASK_PLACEHOLDER,
  );
  result = result.replace(
    /"([A-Za-z0-9_.-]+)"\s*:\s*"([^"]*)"/g,
    (full, key: string) =>
      isSensitiveLogKey(key, extraKeys) ? `"${key}":"${MASK_PLACEHOLDER}"` : full,
  );
  result = result.replace(
    /([A-Za-z0-9_.-]+)\s*([=:])\s*(['"])([^'"]*)\3/g,
    (full, key: string, sep: string, quote: string) =>
      isSensitiveLogKey(key, extraKeys)
        ? `${key}${sep}${quote}${MASK_PLACEHOLDER}${quote}`
        : full,
  );
  result = result.replace(
    /([A-Za-z0-9_.-]+)\s*([=:])\s*([^\s,&;"')\]}]+)/g,
    (full, key: string, sep: string, val: string) => {
      if (!isSensitiveLogKey(key, extraKeys) || val === MASK_PLACEHOLDER) {
        return full;
      }
      return `${key}${sep}${MASK_PLACEHOLDER}`;
    },
  );
  result = result.replace(
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g,
    MASK_PLACEHOLDER,
  );
  result = result.replace(
    /\b(?:\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{1,4}|\d{13,19})\b/g,
    MASK_PLACEHOLDER,
  );
  return result;
}

export interface MaskLogOptions {
  extraKeys?: ReadonlySet<string> | readonly string[];
  maxDepth?: number;
}

export function maskLogValue(
  value: unknown,
  options: MaskLogOptions = {},
): unknown {
  const maxDepth = options.maxDepth ?? 8;
  const visited = new WeakSet<object>();

  const walk = (current: unknown, depth: number): unknown => {
    if (
      current === null ||
      current === undefined ||
      typeof current === "number" ||
      typeof current === "boolean"
    ) {
      return current;
    }
    if (typeof current === "string") {
      return maskLogString(current, options.extraKeys);
    }
    if (typeof current === "bigint") {
      return current.toString();
    }
    if (depth >= maxDepth) {
      return MASK_PLACEHOLDER;
    }
    if (current instanceof Error) {
      return {
        name: current.name,
        message: maskLogString(current.message, options.extraKeys),
      };
    }
    if (current instanceof Headers) {
      const obj: Record<string, unknown> = {};
      for (const [k, v] of current.entries()) {
        obj[k] = isSensitiveLogKey(k, options.extraKeys)
          ? MASK_PLACEHOLDER
          : maskLogString(v, options.extraKeys);
      }
      return obj;
    }
    if (typeof current !== "object") {
      return maskLogString(String(current), options.extraKeys);
    }
    if (visited.has(current)) {
      return "[Circular]";
    }
    visited.add(current);
    try {
      if (Array.isArray(current)) {
        return current.map((item) => walk(item, depth + 1));
      }
      const masked: Record<string, unknown> = {};
      for (const [key, val] of Object.entries(current as Record<string, unknown>)) {
        masked[key] = isSensitiveLogKey(key, options.extraKeys)
          ? MASK_PLACEHOLDER
          : walk(val, depth + 1);
      }
      return masked;
    } finally {
      visited.delete(current);
    }
  };

  return walk(value, 0);
}

export interface RequestResponseMaskSummary {
  requestBody: unknown;
  responseBody: unknown;
  headers: unknown;
}

/**
 * Middleware-style helper returning sanitized request/response summaries for safe logging (#2732).
 */
export function maskPayloadMiddleware(
  input: {
    headers?: Headers | Record<string, string>;
    requestBody?: unknown;
    responseBody?: unknown;
  },
  options: MaskLogOptions = {},
): RequestResponseMaskSummary {
  return {
    headers: input.headers === undefined ? undefined : maskLogValue(input.headers, options),
    requestBody: input.requestBody === undefined ? undefined : maskLogValue(input.requestBody, options),
    responseBody: input.responseBody === undefined ? undefined : maskLogValue(input.responseBody, options),
  };
}

export interface MaskedEdgeLogger {
  info: (message: string, context?: unknown) => void;
  warn: (message: string, context?: unknown) => void;
  error: (message: string, context?: unknown) => void;
}

export function createMaskedLogger(
  sink: (level: "info" | "warn" | "error", message: string, context?: unknown) => void = (
    level,
    message,
    context,
  ) => {
    const line = context === undefined ? message : `${message} ${JSON.stringify(context)}`;
    if (level === "error") {
      console.error(line);
    } else if (level === "warn") {
      console.warn(line);
    } else {
      console.log(line);
    }
  },
  options: MaskLogOptions = {},
): MaskedEdgeLogger {
  const emit = (level: "info" | "warn" | "error", message: string, context?: unknown) => {
    const safeMsg = maskLogString(message, options.extraKeys);
    const safeCtx = context === undefined ? undefined : maskLogValue(context, options);
    sink(level, safeMsg, safeCtx);
  };
  return {
    info: (message, context) => emit("info", message, context),
    warn: (message, context) => emit("warn", message, context),
    error: (message, context) => emit("error", message, context),
  };
}
