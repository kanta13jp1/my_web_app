export type StripeApiErrorDetails = {
  status: number;
  code: string;
  param: string;
};

export class StripeApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    readonly param: string,
    message: string,
  ) {
    super(message);
    this.name = "StripeApiError";
  }
}

export function stripeApiErrorFromResponse(
  status: number,
  data: unknown,
): StripeApiError {
  const root = asRecord(data);
  const error = asRecord(root?.error);
  const code = asString(error?.code);
  const param = asString(error?.param);
  const message = asString(error?.message) || `Stripe API failed: ${status}`;
  return new StripeApiError(status, code, param, message);
}

export function isMissingStripeCustomer(error: unknown): boolean {
  return error instanceof StripeApiError &&
    error.code === "resource_missing" &&
    error.param === "customer";
}

export function stripeApiErrorDetails(
  error: unknown,
): StripeApiErrorDetails | null {
  if (!(error instanceof StripeApiError)) return null;
  return {
    status: error.status,
    code: error.code || "stripe_api_error",
    param: error.param,
  };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
