import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  hasValidWorkerAuthorization,
  isExpectedVideoObject,
  isJobId,
  isLeaseToken,
  isVideoSha256,
  isWorkerErrorCode,
  isWorkerId,
  MAX_VIDEO_BYTES,
  validVideoOutputPaths,
  videoObjectSize,
  videoOutputObject,
} from "./worker_security.ts";

const TOKEN = "0123456789abcdef0123456789abcdef";

Deno.test("worker authorization requires the exact server token", async () => {
  const valid = new Request("https://example.test", {
    headers: { Authorization: `Bearer ${TOKEN}` },
  });
  const invalid = new Request("https://example.test", {
    headers: { Authorization: `Bearer ${TOKEN.slice(0, -1)}x` },
  });
  assertEquals(await hasValidWorkerAuthorization(valid, TOKEN), true);
  assertEquals(await hasValidWorkerAuthorization(invalid, TOKEN), false);
  assertEquals(await hasValidWorkerAuthorization(valid, "short"), false);
});

Deno.test("worker identifiers and lease tokens are narrowly validated", () => {
  assertEquals(isWorkerId("gpu-worker_01"), true);
  assertEquals(isWorkerId("../../escape"), false);
  assertEquals(isJobId("11111111-1111-4111-8111-111111111111"), true);
  assertEquals(isJobId("not-a-job"), false);
  assertEquals(isLeaseToken("ab".repeat(32)), true);
  assertEquals(isLeaseToken("z".repeat(64)), false);
  assertEquals(isWorkerErrorCode("inference_failed"), true);
  assertEquals(isWorkerErrorCode("inference_gpu_memory_exhausted"), true);
  assertEquals(isWorkerErrorCode("inference_host_memory_exhausted"), true);
  assertEquals(isWorkerErrorCode("inference_memory_exhausted"), true);
  assertEquals(isWorkerErrorCode("inference_process_failed"), true);
  assertEquals(isWorkerErrorCode("raw exception text"), false);
});

Deno.test("only the exact bounded mp4 output is accepted", () => {
  const valid = {
    name: "job.mp4",
    metadata: { size: 1024, mimetype: "video/mp4" },
  };
  assertEquals(isExpectedVideoObject(valid, "job.mp4"), true);
  assertEquals(videoObjectSize(valid), 1024);
  assertEquals(isVideoSha256("a".repeat(64)), true);
  assertEquals(isVideoSha256("A".repeat(64)), false);
  assertEquals(isExpectedVideoObject(valid, "other.mp4"), false);
  assertEquals(
    isExpectedVideoObject(
      { name: "job.mp4", metadata: { size: 1024, mimetype: "text/html" } },
      "job.mp4",
    ),
    false,
  );
  assertEquals(
    isExpectedVideoObject(
      {
        name: "job.mp4",
        metadata: { size: MAX_VIDEO_BYTES + 1, mimetype: "video/mp4" },
      },
      "job.mp4",
    ),
    false,
  );
});

Deno.test("output paths are isolated by user, job, and bounded attempt", () => {
  const validPath = "11111111-1111-4111-8111-111111111111/" +
    "22222222-2222-4222-8222-222222222222-attempt-2.mp4";
  assertEquals(
    videoOutputObject(validPath),
    {
      folder: "11111111-1111-4111-8111-111111111111",
      name: "22222222-2222-4222-8222-222222222222-attempt-2.mp4",
    },
  );
  assertEquals(
    videoOutputObject(
      "11111111-1111-4111-8111-111111111111/" +
        "22222222-2222-4222-8222-222222222222-attempt-4.mp4",
    ),
    null,
  );
  assertEquals(videoOutputObject("../escape.mp4"), null);
  assertEquals(validVideoOutputPaths([validPath, "../escape.mp4"]), [
    validPath,
  ]);
  assertEquals(validVideoOutputPaths([validPath, validPath, validPath]), []);
});
