export type InventoryExpansionCandidate = {
  id: string;
  source_id: string;
  source_kind: string;
  metadata?: Record<string, unknown> | null;
};

const EXPANDABLE_SOURCE_KINDS = new Set([
  "page",
  "database",
  "data_source",
]);

export async function inventoryExpansionPlanSha256(
  candidates: readonly InventoryExpansionCandidate[],
): Promise<string> {
  const material = candidates.map((candidate) => {
    const id = String(candidate.id ?? "").trim().toLowerCase();
    const sourceId = String(candidate.source_id ?? "").trim().toLowerCase();
    const sourceKind = String(candidate.source_kind ?? "").trim();
    if (
      id === "" ||
      sourceId === "" ||
      sourceId.length > 512 ||
      !EXPANDABLE_SOURCE_KINDS.has(sourceKind)
    ) {
      throw new Error("invalid_inventory_expansion_candidate");
    }
    const metadata = candidate.metadata &&
        typeof candidate.metadata === "object" &&
        !Array.isArray(candidate.metadata)
      ? candidate.metadata
      : {};
    const cursor = typeof metadata.inventory_cursor === "string"
      ? metadata.inventory_cursor
      : null;
    return {
      id,
      source_id: sourceId,
      source_kind: sourceKind,
      inventory_cursor: cursor,
    };
  });
  const bytes = new TextEncoder().encode(JSON.stringify(material));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}
