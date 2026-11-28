import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const vendorDir = path.join(rootDir, 'vendor');
const manifestPath = path.join(rootDir, 'manifest.json');

const VENDOR_FILES = [
  {
    src: path.join(rootDir, 'node_modules', '@mozilla', 'readability', 'Readability.js'),
    dest: path.join(vendorDir, 'Readability.js'),
    label: '@mozilla/readability (Apache-2.0)',
  },
  {
    src: path.join(rootDir, 'node_modules', 'turndown', 'dist', 'turndown.js'),
    dest: path.join(vendorDir, 'turndown.js'),
    label: 'turndown (MIT)',
  },
];

function validateManifest() {
  const raw = fs.readFileSync(manifestPath, 'utf8');
  const manifest = JSON.parse(raw);
  if (manifest.manifest_version !== 3) {
    throw new Error(`manifest_version must be 3, got ${manifest.manifest_version}`);
  }
  const perms = manifest.permissions ?? [];
  for (const required of ['activeTab', 'scripting', 'storage']) {
    if (!perms.includes(required)) {
      throw new Error(`manifest.json missing required permission: ${required}`);
    }
  }
  const hostPerms = manifest.host_permissions ?? [];
  if (hostPerms.includes('<all_urls>') || hostPerms.includes('*://*/*')) {
    throw new Error('manifest.json must not request broad host_permissions');
  }
}

function main() {
  validateManifest();
  fs.mkdirSync(vendorDir, { recursive: true });
  for (const entry of VENDOR_FILES) {
    if (!fs.existsSync(entry.src)) {
      throw new Error(
        `Missing ${entry.label} at ${entry.src}. Run "npm install" inside tools/web_clipper first.`,
      );
    }
    fs.copyFileSync(entry.src, entry.dest);
    console.log(`Bundled ${entry.label} -> ${path.relative(rootDir, entry.dest)}`);
  }
}

main();
