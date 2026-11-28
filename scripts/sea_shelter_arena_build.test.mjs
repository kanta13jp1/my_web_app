import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { cp, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import {
  engineFiles,
  sha256,
  verifyArena,
} from "./verify_sea_shelter_arena.mjs";
test("default preview is ignored and preserves source plus original ignore bytes", async () => {
  const sourceStatus = () =>
    execFileSync("git", [
      "status",
      "--porcelain",
      "--untracked-files=all",
      "--",
      "web/labs/sea-shelter",
      ".gitignore",
    ]).toString();
  const before = sourceStatus();
  const ignore = await readFile(".gitignore");
  assert.throws(
    () =>
      execFileSync(process.execPath, [
        "scripts/build_sea_shelter_arena.mjs",
        "web",
      ], { stdio: "pipe" }),
    /never the source web directory/,
  );
  execFileSync(process.execPath, ["scripts/build_sea_shelter_arena.mjs"]);
  const preview = "build/sea-shelter-preview";
  await verifyArena(preview);
  for (
    const file of ["arena/vendor/three.module.js", "arena/engine-build.json"]
  ) {
    execFileSync("git", [
      "check-ignore",
      "--quiet",
      "--",
      `${preview}/labs/sea-shelter/${file}`,
    ]);
  }
  for (
    const file of ["index.html", "app.mjs", "assets/residents-original-v2.png"]
  ) {
    assert.deepEqual(
      await readFile(`${preview}/labs/sea-shelter/${file}`),
      await readFile(`web/labs/sea-shelter/${file}`),
    );
  }
  assert.deepEqual(await readFile(".gitignore"), ignore);
  assert.equal(sourceStatus(), before);
});
test("post-build packaging is reproducible and rejects missing, corrupt and mismatched assets", async () => {
  const temp = await mkdtemp(resolve(tmpdir(), "arena-packaging-"));
  try {
    const roots = [resolve(temp, "a"), resolve(temp, "b")];
    for (const root of roots) {
      await cp("web", root, { recursive: true });
      // Simulate a fresh Flutter build without ignored generated assets.
      await rm(resolve(root, "labs/sea-shelter/arena/vendor"), {
        recursive: true,
        force: true,
      });
      execFileSync(process.execPath, [
        "scripts/build_sea_shelter_arena.mjs",
        root,
      ]);
    }
    const a = await verifyArena(roots[0]), b = await verifyArena(roots[1]);
    assert.deepEqual(a, b);
    for (const file of engineFiles) {
      assert.equal(a.files[file].sha256, b.files[file].sha256);
    }
    const dir = resolve(roots[0], "labs/sea-shelter/arena");
    const modulePath = resolve(dir, "vendor/three.module.js");
    const original = await readFile(modulePath);
    await writeFile(modulePath, "corrupted");
    await assert.rejects(verifyArena(roots[0]), /integrity/);
    await rm(modulePath);
    await assert.rejects(verifyArena(roots[0]), /ENOENT/);
    await writeFile(modulePath, original);
    const manifestPath = resolve(dir, "engine-build.json");
    await writeFile(manifestPath, JSON.stringify({ ...a, version: "wrong" }));
    await assert.rejects(verifyArena(roots[0]), /manifest/);
    await writeFile(manifestPath, JSON.stringify({ ...a, bytes: 2000001 }));
    await assert.rejects(verifyArena(roots[0]), /budget/);
    const licensePath = resolve(dir, "vendor/LICENSE.txt");
    const badLicense = Buffer.from("missing attribution");
    await writeFile(licensePath, badLicense);
    await writeFile(
      manifestPath,
      JSON.stringify({
        ...a,
        files: {
          ...a.files,
          "LICENSE.txt": {
            bytes: badLicense.length,
            sha256: sha256(badLicense),
          },
        },
      }),
    );
    await assert.rejects(verifyArena(roots[0]), /attribution/);
    await rm(resolve(dir, "scene.mjs"));
    await cp(
      resolve(roots[1], "labs/sea-shelter/arena/vendor/LICENSE.txt"),
      licensePath,
    );
    await writeFile(manifestPath, JSON.stringify(a));
    await assert.rejects(verifyArena(roots[0]), /ENOENT/);
  } finally {
    await rm(temp, { recursive: true, force: true });
  }
});
