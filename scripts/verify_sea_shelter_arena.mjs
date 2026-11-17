// Fail closed before artifact publication or Hosting deployment.
import { createHash } from "node:crypto";
import { lstat, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
export const engineFiles = ["three.module.js", "three.core.js", "LICENSE.txt"];
export const sha256 = (data) => createHash("sha256").update(data).digest("hex");
export async function verifyArena(webRoot) {
  const root = resolve(webRoot, "labs/sea-shelter/arena");
  const manifest = JSON.parse(
    await readFile(resolve(root, "engine-build.json"), "utf8"),
  );
  if (
    manifest.version !== "0.186.0" || manifest.minifier !== "0.28.2" ||
    JSON.stringify(Object.keys(manifest.files ?? {}).sort()) !==
      JSON.stringify([...engineFiles].sort())
  ) {
    throw Error("Unexpected arena engine manifest");
  }
  let bytes = 0;
  for (const name of engineFiles) {
    const path = resolve(root, "vendor", name);
    if (!(await lstat(path)).isFile()) {
      throw Error("Engine asset must be a regular file");
    }
    const data = await readFile(path);
    const item = manifest.files[name];
    if (!item || item.bytes !== data.length || item.sha256 !== sha256(data)) {
      throw Error(`Engine integrity mismatch: ${name}`);
    }
    if (name !== "LICENSE.txt") bytes += data.length;
    else if (
      !data.toString().includes("MIT License") ||
      !data.toString().includes("Copyright")
    ) throw Error("Missing MIT attribution");
  }
  if (bytes !== manifest.bytes || bytes < 100000 || bytes > 2000000) {
    throw Error("Invalid engine transfer budget");
  }
  const module = await readFile(
    resolve(root, "vendor/three.module.js"),
    "utf8",
  );
  if (!module.includes("./three.core.js")) {
    throw Error("Engine core is not a same-origin sibling");
  }
  for (
    const name of [
      "index.html",
      "controller.mjs",
      "model.mjs",
      "scene.mjs",
      "actors.mjs",
      "arena.css",
    ]
  ) {
    if (!(await lstat(resolve(root, name))).isFile()) {
      throw Error(`Missing arena source: ${name}`);
    }
  }
  const scene = await readFile(resolve(root, "scene.mjs"), "utf8");
  if (!scene.includes('"./vendor/three.module.js"')) {
    throw Error("Scene is not connected to packaged engine");
  }
  return manifest;
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  const result = await verifyArena(process.argv[2] ?? "build/web");
  console.log(
    `Verified Three.js ${result.version}: ${result.bytes} bytes, license and SHA-256 checked`,
  );
}
