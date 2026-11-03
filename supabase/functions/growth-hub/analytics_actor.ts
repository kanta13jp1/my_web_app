function firstForwardedAddress(value: string | null): string {
  return value?.split(",", 1)[0]?.trim() || "unknown";
}

export function analyticsActorMaterial(
  req: Request,
  userId: string | null,
): string {
  if (userId) return `user:${userId}`;

  const address = req.headers.get("cf-connecting-ip")?.trim() ||
    req.headers.get("x-real-ip")?.trim() ||
    firstForwardedAddress(req.headers.get("x-forwarded-for"));
  return `anonymous:${address}`;
}

export async function analyticsActorHash(
  req: Request,
  userId: string | null,
): Promise<string> {
  const bytes = new TextEncoder().encode(analyticsActorMaterial(req, userId));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
