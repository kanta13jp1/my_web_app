// Fail closed before artifact publication or Hosting deployment.
import { createHash } from "node:crypto";
import { lstat, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

export const ALPHATAB_VERSION = "1.9.0";
export const ALPHATAB_LICENSE = "MPL-2.0";

export const vendorFiles = [
  "alphaTab.min.mjs",
  "alphaTab.core.min.mjs",
  "alphaTab.worker.min.mjs",
  "alphaTab.worklet.min.mjs",
  "LICENSE.txt",
  "font/Bravura.woff2",
  "font/Bravura-OFL.txt",
  "soundfont/sonivox.sf3",
  "soundfont/LICENSE.txt",
];

const licenseAssertions = new Map([
  ["LICENSE.txt", ["Mozilla Public License", "2.0"]],
  ["font/Bravura-OFL.txt", ["SIL OPEN FONT LICENSE"]],
  ["soundfont/LICENSE.txt", ["Apache License", "2.0"]],
]);

export const sha256 = (data) => createHash("sha256").update(data).digest("hex");

export async function verifyGuitarProLab(webRoot) {
  const labRoot = resolve(webRoot, "labs/guitar-pro-studio");
  const manifest = JSON.parse(
    await readFile(resolve(labRoot, "engine-build.json"), "utf8"),
  );
  if (
    manifest.version !== ALPHATAB_VERSION ||
    manifest.license !== ALPHATAB_LICENSE ||
    JSON.stringify(Object.keys(manifest.files ?? {}).sort()) !==
      JSON.stringify([...vendorFiles].sort())
  ) {
    throw Error("Unexpected Guitar Pro lab engine manifest");
  }

  let runtimeBytes = 0;
  for (const name of vendorFiles) {
    const filePath = resolve(labRoot, "vendor", name);
    if (!(await lstat(filePath)).isFile()) {
      throw Error(`Vendor asset must be a regular file: ${name}`);
    }
    const data = await readFile(filePath);
    const entry = manifest.files[name];
    if (
      !entry ||
      entry.bytes !== data.length ||
      entry.sha256 !== sha256(data)
    ) {
      throw Error(`Vendor asset integrity mismatch: ${name}`);
    }
    const expectedMarkers = licenseAssertions.get(name);
    if (expectedMarkers) {
      const text = data.toString("utf8");
      for (const marker of expectedMarkers) {
        if (!text.includes(marker)) {
          throw Error(`Missing license attribution (${marker}) in ${name}`);
        }
      }
    } else {
      runtimeBytes += data.length;
    }
  }

  if (
    runtimeBytes !== manifest.bytes ||
    runtimeBytes < 500_000 ||
    runtimeBytes > 3_000_000
  ) {
    throw Error(`Invalid Guitar Pro lab payload budget: ${runtimeBytes}`);
  }

  for (const name of ["index.html", "style.css", "app.mjs", "presets.mjs"]) {
    const srcPath = resolve(labRoot, name);
    if (!(await lstat(srcPath)).isFile()) {
      throw Error(`Missing Guitar Pro lab source: ${name}`);
    }
  }

  const appSource = await readFile(resolve(labRoot, "app.mjs"), "utf8");
  if (!appSource.includes('"./vendor/alphaTab.min.mjs"')) {
    throw Error("app.mjs is not connected to packaged same-origin alphaTab");
  }
  for (const forbiddenHost of [
    "cdn.jsdelivr.net",
    "unpkg.com",
    "cdnjs.cloudflare.com",
  ]) {
    if (appSource.includes(forbiddenHost)) {
      throw Error(`External CDN reference is forbidden: ${forbiddenHost}`);
    }
  }

  return manifest;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  const result = await verifyGuitarProLab(
    process.argv[2] ?? "build/guitar-pro-preview",
  );
  console.log(
    `Verified alphaTab ${result.version} (${result.license}): ${result.bytes} bytes`,
  );
}
