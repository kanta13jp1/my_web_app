function isBlockedIpv4(host: string): boolean {
  const parts = host.split(".");
  if (parts.length !== 4) return false;
  const octets = parts.map((p) => Number(p));
  if (octets.some((o) => !Number.isInteger(o) || o < 0 || o > 255)) {
    return false;
  }
  const [a, b] = octets;
  if (a === 0 || a === 10 || a === 127 || a >= 224) return true;
  if (a === 169 && b === 254) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  if (a === 100 && b >= 64 && b <= 127) return true;
  return false;
}

function isBlockedIpv6(host: string): boolean {
  const bare = host.replace(/^\[|\]$/g, "").toLowerCase();
  if (!bare.includes(":")) return false;
  if (bare === "::" || bare === "::1") return true;
  if (bare.startsWith("fc") || bare.startsWith("fd")) return true;
  if (/^fe[89ab][0-9a-f]:/i.test(bare)) return true;
  if (bare.startsWith("::ffff:")) {
    const tail = bare.slice("::ffff:".length);
    if (isBlockedIpv4(tail)) return true;
  }
  return false;
}

export function validateProbeUrl(rawUrl: string): {
  ok: boolean;
  normalizedUrl: string;
  reason?: string;
} {
  const trimmed = rawUrl.trim();
  if (!trimmed) {
    return {
      ok: false,
      normalizedUrl: "",
      reason: "endpoint_url is required.",
    };
  }
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return {
      ok: false,
      normalizedUrl: "",
      reason: "endpoint_url must be a valid URL.",
    };
  }
  if (parsed.protocol !== "https:") {
    return {
      ok: false,
      normalizedUrl: "",
      reason: "Only https:// URLs are allowed for healthcheck probes.",
    };
  }
  if (parsed.username || parsed.password) {
    return {
      ok: false,
      normalizedUrl: "",
      reason: "Credentials inside endpoint_url are not allowed.",
    };
  }
  const host = parsed.hostname.toLowerCase().replace(/\.$/, "");
  if (
    !host ||
    host === "localhost" ||
    host.endsWith(".localhost") ||
    host.endsWith(".local") ||
    host.endsWith(".internal")
  ) {
    return {
      ok: false,
      normalizedUrl: "",
      reason: "Private or localhost probe host is not allowed.",
    };
  }
  if (isBlockedIpv4(host) || isBlockedIpv6(host)) {
    return {
      ok: false,
      normalizedUrl: "",
      reason: "Private, loopback, or link-local IP addresses are blocked.",
    };
  }
  return { ok: true, normalizedUrl: parsed.toString() };
}
