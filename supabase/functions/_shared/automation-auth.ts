const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const ADMIN_EMAIL = Deno.env.get("ADMIN_EMAIL") ?? "";
const AUTOMATION_ADMIN_EMAILS = Deno.env.get("AUTOMATION_ADMIN_EMAILS") ?? "";

// deno-lint-ignore no-explicit-any
type AdminClient = any;

export type AutomationActor = {
  mode: "service_role" | "admin_user";
  email?: string;
  userId?: string;
};

export async function authorizeAutomationActor(
  admin: AdminClient,
  req: Request,
): Promise<AutomationActor> {
  const token = getBearerToken(req);
  if (token === "") {
    throw new Error("Authorization token is required.");
  }

  if (SERVICE_ROLE_KEY !== "" && token === SERVICE_ROLE_KEY) {
    return { mode: "service_role" };
  }

  const { data, error } = await admin.auth.getUser(token);
  if (error) throw error;

  const user = data.user;
  if (!user) {
    throw new Error("Authenticated user not found.");
  }

  const email = user.email?.trim().toLowerCase() ?? "";
  const allowedEmails = getAllowedAdminEmails();
  if (allowedEmails.size === 0) {
    throw new Error(
      "Admin allowlist is not configured. Set ADMIN_EMAIL or AUTOMATION_ADMIN_EMAILS in Supabase secrets.",
    );
  }
  if (email === "" || !allowedEmails.has(email)) {
    throw new Error(
      "Forbidden. This user is not allowed to access automation controls.",
    );
  }

  return {
    mode: "admin_user",
    email,
    userId: user.id,
  };
}

// Extracts the bearer token from either the Authorization header (preferred)
// or the ?token= / ?apikey= URL query param (fallback for WebFetch which
// cannot set custom headers, used by WEB版 Claude Schedule).
function getBearerToken(req: Request): string {
  const authHeader = req.headers.get("authorization") ?? "";
  if (authHeader.toLowerCase().startsWith("bearer ")) {
    return authHeader.slice(7).trim();
  }

  try {
    const url = new URL(req.url);
    const param = url.searchParams.get("token") ??
      url.searchParams.get("apikey") ?? "";
    return param.trim();
  } catch {
    return "";
  }
}

function getAllowedAdminEmails(): Set<string> {
  const emails = [
    ADMIN_EMAIL,
    ...AUTOMATION_ADMIN_EMAILS.split(","),
  ]
    .map((value) => value.trim().toLowerCase())
    .filter((value) => value !== "");

  return new Set(emails);
}
