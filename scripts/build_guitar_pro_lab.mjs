// Build-only dependency delivery for /labs/guitar-pro-studio.
// No CDN, no runtime package resolution, and no binary files checked into Git.
import { access, cp, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve, sep } from "node:path";
import {
  ALPHATAB_LICENSE,
  ALPHATAB_VERSION,
  sha256,
  verifyGuitarProLab,
} from "./verify_guitar_pro_lab.mjs";

const root = resolve(import.meta.dirname, "..");
const args = process.argv.slice(2);
const standaloneFlag = args.includes("--standalone");
const positional = args.filter((arg) => !arg.startsWith("--"));

const webRoot = resolve(root, positional[0] ?? "build/guitar-pro-preview");
const sourceWebRoot = resolve(root, "web");
if (
  webRoot === sourceWebRoot ||
  webRoot.startsWith(sourceWebRoot + sep)
) {
  throw Error("Generate into a build output, never the source web directory");
}

const pkgDir = resolve(root, "node_modules/@coderline/alphatab");
const pkg = JSON.parse(await readFile(resolve(pkgDir, "package.json"), "utf8"));
if (pkg.version !== ALPHATAB_VERSION || pkg.license !== ALPHATAB_LICENSE) {
  throw Error(`Unexpected @coderline/alphatab package: ${pkg.version}`);
}

const labOutput = resolve(webRoot, "labs/guitar-pro-studio");
const hasLabHtml = await access(resolve(labOutput, "index.html"))
  .then(() => true)
  .catch(() => false);

if (standaloneFlag || positional.length === 0 || !hasLabHtml) {
  await cp(resolve(sourceWebRoot, "labs/guitar-pro-studio"), labOutput, {
    recursive: true,
  });
}

const copyMap = [
  ["dist/alphaTab.min.mjs", "alphaTab.min.mjs"],
  ["dist/alphaTab.core.min.mjs", "alphaTab.core.min.mjs"],
  ["dist/alphaTab.worker.min.mjs", "alphaTab.worker.min.mjs"],
  ["dist/alphaTab.worklet.min.mjs", "alphaTab.worklet.min.mjs"],
  ["LICENSE", "LICENSE.txt"],
  ["dist/font/Bravura.woff2", "font/Bravura.woff2"],
  ["dist/font/Bravura-OFL.txt", "font/Bravura-OFL.txt"],
  ["dist/soundfont/sonivox.sf3", "soundfont/sonivox.sf3"],
  ["dist/soundfont/LICENSE", "soundfont/LICENSE.txt"],
];

const vendorDir = resolve(labOutput, "vendor");
const filesManifest = {};
let runtimeBytes = 0;

for (const [srcRel, destRel] of copyMap) {
  const data = await readFile(resolve(pkgDir, srcRel));
  const destPath = resolve(vendorDir, destRel);
  await mkdir(dirname(destPath), { recursive: true });
  await writeFile(destPath, data);
  filesManifest[destRel] = {
    bytes: data.length,
    sha256: sha256(data),
  };
  if (!destRel.endsWith("LICENSE.txt") && !destRel.endsWith("-OFL.txt")) {
    runtimeBytes += data.length;
  }
}

await writeFile(
  resolve(labOutput, "engine-build.json"),
  JSON.stringify(
    {
      version: pkg.version,
      license: pkg.license,
      bytes: runtimeBytes,
      files: filesManifest,
    },
    null,
    2,
  ) + "\n",
);

await verifyGuitarProLab(webRoot);
console.log(
  `alphaTab ${pkg.version} (${pkg.license}): ${runtimeBytes} bytes -> ${vendorDir}`,
);
