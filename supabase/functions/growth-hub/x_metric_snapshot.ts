export function compactXMetricSnapshotMedia(
  metadata: Record<string, unknown>,
): { has_media: boolean } {
  return { has_media: Boolean(metadata.media_url) };
}
