import { createReadStream, promises as fs } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';

const root = path.resolve(process.argv[2] ?? 'build/web');
const host = process.env.HOST ?? '127.0.0.1';
const port = Number(process.env.PORT ?? '7357');

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.wasm', 'application/wasm'],
  ['.webmanifest', 'application/manifest+json'],
]);

function safePathname(requestUrl) {
  const pathname = decodeURIComponent(new URL(requestUrl, `http://${host}`).pathname);
  const relativePath = pathname.replace(/^\/+/, '');
  const candidate = path.resolve(root, relativePath);

  if (candidate !== root && !candidate.startsWith(`${root}${path.sep}`)) {
    return null;
  }

  return candidate;
}

async function resolveFile(requestUrl) {
  const candidate = safePathname(requestUrl);
  if (candidate === null) {
    return null;
  }

  try {
    const stat = await fs.stat(candidate);
    if (stat.isFile()) {
      return candidate;
    }
    if (stat.isDirectory()) {
      const indexFile = path.join(candidate, 'index.html');
      const indexStat = await fs.stat(indexFile);
      if (indexStat.isFile()) {
        return indexFile;
      }
    }
  } catch {
    // Flutter Web uses path-based routing, so unknown paths fall back to index.
  }

  return path.join(root, 'index.html');
}

const server = createServer(async (request, response) => {
  try {
    const file = await resolveFile(request.url ?? '/');
    if (file === null) {
      response.writeHead(400).end('Bad request');
      return;
    }

    const stat = await fs.stat(file);
    response.writeHead(200, {
      'Cache-Control': 'no-store',
      'Content-Length': stat.size,
      'Content-Type': contentTypes.get(path.extname(file)) ?? 'application/octet-stream',
      'X-Content-Type-Options': 'nosniff',
    });
    createReadStream(file).pipe(response);
  } catch (error) {
    response.writeHead(500).end('Unable to serve Flutter Web build');
    process.stderr.write(`${error instanceof Error ? error.stack : error}\n`);
  }
});

server.listen(port, host, () => {
  process.stdout.write(`Flutter SPA server listening on http://${host}:${port}\n`);
});

function shutdown() {
  server.close(() => process.exit(0));
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
