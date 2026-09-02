function sanitizeSegment(value: string): string {
  const withoutControls = Array.from(value, (character) => {
    const codePoint = character.codePointAt(0) ?? 0;
    return codePoint < 32 || codePoint === 127 ? "_" : character;
  }).join("");
  return withoutControls
    .trim()
    .replace(/[\/\\]/g, "_")
    .replace(/\s+/g, " ")
    .replace(/_+/g, "_");
}

/// Content-Dispositionに渡す保存名。DB制約に加え、Edge Functionでも
/// パス区切りと制御文字を除去して多層防御にする。
export function safeDownloadFileName(
  configuredName: string,
  productId: string,
  version: string,
): string {
  const fallbackId = sanitizeSegment(productId) || "digital-product";
  const fallbackVersion = sanitizeSegment(version) || "1.0";
  const configured = sanitizeSegment(configuredName);
  const candidate = configured && configured !== "." && configured !== ".."
    ? configured
    : `${fallbackId}-v${fallbackVersion}.zip`;
  return candidate.slice(0, 180);
}
