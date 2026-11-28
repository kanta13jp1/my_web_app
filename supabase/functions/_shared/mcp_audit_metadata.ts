/** Audit payloads deliberately exclude every argument key and value.
 * A denylist cannot protect secrets embedded in ordinary text or unknown keys.
 * Do not inspect properties, call toJSON/toString, or traverse caller objects.
 * tool/status/client/time remain in the surrounding audit event.
 */
export function auditArgumentMetadata(value: unknown): {
  policy: string;
  redacted: boolean;
  input_type: string;
} {
  return {
    policy: "metadata_only_v1",
    redacted: true,
    input_type: value === null ? "null" : typeof value,
  };
}
