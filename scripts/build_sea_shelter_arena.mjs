// Build-only dependency delivery. No CDN, runtime package resolution or network.
import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
const root = resolve(import.meta.dirname, "..");
const pkg = JSON.parse(
  await readFile(resolve(root, "node_modules/three/package.json"), "utf8"),
);
if (pkg.version !== "0.186.0" || pkg.license !== "MIT") {
  throw Error("Unexpected Three.js package");
}
const output = resolve(
  root,
  process.argv[2] ?? "web",
  "labs/sea-shelter/arena/vendor",
);
await mkdir(output, { recursive: true });
const files = ["three.module.min.js", "three.core.min.js"];
let total = 0;
for (const file of files) {
  const source = resolve(root, "node_modules/three/build", file);
  total += (await readFile(source)).length;
  await copyFile(source, resolve(output, file));
}
await copyFile(
  resolve(root, "node_modules/three/LICENSE"),
  resolve(output, "LICENSE.txt"),
);
if (total > 2_000_000) throw Error("Engine exceeds the lazy transfer budget");
await writeFile(
  resolve(dirname(output), "engine-build.json"),
  JSON.stringify({ version: pkg.version, bytes: total, files }),
);
console.log(`Three.js ${pkg.version}: ${total} bytes, same-origin ${output}`);
