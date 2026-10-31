// Build-only dependency delivery. No CDN, runtime package resolution or network.
import { cp, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve, sep } from "node:path";
import esbuild from "esbuild-wasm";
import {
  engineFiles,
  sha256,
  verifyArena,
} from "./verify_sea_shelter_arena.mjs";
if (esbuild.version !== "0.28.2") throw Error("Unexpected build minifier");
const root = resolve(import.meta.dirname, "..");
const pkg = JSON.parse(
  await readFile(resolve(root, "node_modules/three/package.json"), "utf8"),
);
if (pkg.version !== "0.186.0" || pkg.license !== "MIT") {
  throw Error("Unexpected Three.js package");
}
const webRoot = resolve(root, process.argv[2] ?? "build/sea-shelter-preview");
const sourceRoot = resolve(root, "web");
if (webRoot === sourceRoot || webRoot.startsWith(sourceRoot + sep)) {
  throw Error("Generate into a build output, never the source web directory");
}
if (!process.argv[2]) {
  // Preview only: keep source and its existing ignore rules byte-for-byte intact.
  await cp(
    resolve(root, "web/labs/sea-shelter"),
    resolve(webRoot, "labs/sea-shelter"),
    { recursive: true },
  );
}
const output = resolve(webRoot, "labs/sea-shelter/arena/vendor");
await mkdir(output, { recursive: true });
const files = ["three.module.js", "three.core.js"];
let total = 0;
const assets = {};
for (const file of files) {
  const source = resolve(root, "node_modules/three/build", file);
  const { code } = await esbuild.transform(await readFile(source, "utf8"), {
    minify: true,
    format: "esm",
    target: "es2022",
    legalComments: "inline",
  });
  total += Buffer.byteLength(code);
  assets[file] = { bytes: Buffer.byteLength(code), sha256: sha256(code) };
  await writeFile(resolve(output, file), code);
}
const license = await readFile(resolve(root, "node_modules/three/LICENSE"));
await writeFile(resolve(output, "LICENSE.txt"), license);
assets[engineFiles[2]] = { bytes: license.length, sha256: sha256(license) };
if (total > 2_000_000) throw Error("Engine exceeds the lazy transfer budget");
await writeFile(
  resolve(dirname(output), "engine-build.json"),
  JSON.stringify({
    version: pkg.version,
    minifier: esbuild.version,
    bytes: total,
    files: assets,
  }),
);
await verifyArena(webRoot);
console.log(`Three.js ${pkg.version}: ${total} bytes, same-origin ${output}`);
