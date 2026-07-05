'use strict';
// caption-transcoder — a tiny stateless ffmpeg burn-in service for the
// viral-video-ad-generator edge function (H3 / muted-autoplay dwell time).
//
// Contract (must match supabase/functions/viral-video-ad-generator/captions.ts):
//   POST /burn  (auth: Authorization: Bearer <API_KEY>  OR  x-api-key: <API_KEY>)
//     body: { videoUrl, mp4Url, srt, subtitleFormat:"srt", format:"mp4",
//             resolution:"540p", style:{...}, forceStyle:"FontName=...,FontSize=..." }
//     -> downloads the mp4, burns the SRT with force_style, and returns { url }
//        pointing at a short-lived self-served file. The edge function fetches that
//        url ONCE and re-persists it to Supabase Storage, so the url only needs to
//        live for a few seconds — no GCS/object store required.
//   GET /file/:id.mp4  -> streams the burned result (deleted after a short TTL).
//   GET /healthz       -> ok.
//
// Deploy as Cloud Run with --max-instances=1 so the GET /file hits the same
// instance that produced it (see README). No npm dependencies (plain Node core).

const http = require('http');
const https = require('https');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 8080;
const API_KEY = (process.env.API_KEY || '').trim();
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || '').trim();
const FILE_TTL_MS = Number(process.env.FILE_TTL_MS || 10 * 60 * 1000);
const OUT_DIR = path.join(os.tmpdir(), 'caption-out');
fs.mkdirSync(OUT_DIR, { recursive: true });

function authed(req) {
  if (!API_KEY) return true; // auth optional; set API_KEY to require it
  const bearer = String(req.headers['authorization'] || '')
    .replace(/^Bearer\s+/i, '')
    .trim();
  const xkey = String(req.headers['x-api-key'] || '').trim();
  return bearer === API_KEY || xkey === API_KEY;
}

function download(url, dest, redirects) {
  return new Promise((resolve, reject) => {
    if ((redirects || 0) > 5) return reject(new Error('too many redirects'));
    const mod = url.startsWith('http:') ? http : https;
    const request = mod.get(url, (resp) => {
      if (
        resp.statusCode >= 300 &&
        resp.statusCode < 400 &&
        resp.headers.location
      ) {
        resp.resume();
        return download(resp.headers.location, dest, (redirects || 0) + 1).then(
          resolve,
          reject,
        );
      }
      if (resp.statusCode !== 200) {
        resp.resume();
        return reject(new Error('download status ' + resp.statusCode));
      }
      const file = fs.createWriteStream(dest);
      resp.pipe(file);
      file.on('finish', () => file.close(() => resolve()));
      file.on('error', reject);
    });
    request.on('error', reject);
    request.setTimeout(120000, () => request.destroy(new Error('download timeout')));
  });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 5_000_000) req.destroy(new Error('body too large'));
    });
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

function resolutionHeight(resolution) {
  const match = /(\d{3,4})p/.exec(String(resolution || ''));
  return match ? parseInt(match[1], 10) : null;
}

// ffmpeg subtitles filter needs the srt path escaped and force_style single-quoted
// so its internal commas are not parsed as filtergraph option separators.
// The filename itself is ALSO single-quoted (with the drive colon backslash-
// escaped): unquoted, a Windows path like C:/Users/... is split at the colon
// and ffmpeg mis-parses the remainder as filter options (observed:
// "Unable to parse 'original_size' option"). Harmless on Linux paths.
function buildVideoFilter(srtPath, forceStyle, scaleHeight) {
  const escaped = srtPath.replace(/\\/g, '/').replace(/:/g, '\\:');
  let sub = "subtitles='" + escaped + "'";
  if (forceStyle) sub += ":force_style='" + forceStyle + "'";
  return scaleHeight ? 'scale=-2:' + scaleHeight + ',' + sub : sub;
}

// --- SRT rescale to the real media duration (desync fix) -------------------
// The edge function estimates cue times from a fixed chars/sec rate, which
// drifts against the real ElevenLabs speech rate. The mp4 is already local,
// so ffprobe the REAL duration and linearly rescale all cue times to fit
// [leadInMs, duration - tailPadMs]. Every guard failure returns the input
// unchanged — rescaling can never break a burn.

const SRT_TIME_RE =
  /(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})/g;

function srtTimeToMs(h, m, s, ms) {
  return ((Number(h) * 60 + Number(m)) * 60 + Number(s)) * 1000 + Number(ms);
}

function msToSrtTime(total) {
  const t = Math.max(0, Math.round(total));
  const pad = (v, w) => String(v).padStart(w || 2, '0');
  return (
    pad(Math.floor(t / 3600000)) + ':' + pad(Math.floor(t / 60000) % 60) +
    ':' + pad(Math.floor(t / 1000) % 60) + ',' + pad(t % 1000, 3)
  );
}

// ffprobe the real media duration (ms). Audio stream first (speech ends with
// audio; -c:a copy keeps it authoritative), container format as fallback.
// Resolves null on any failure/timeout — caller treats null as "skip rescale".
function ffprobeDurationMs(filePath, timeoutMs) {
  const probe = (args) => new Promise((resolve) => {
    const p = spawn(
      'ffprobe',
      ['-v', 'error'].concat(args, ['-of', 'csv=p=0', filePath]),
      { stdio: ['ignore', 'pipe', 'ignore'] },
    );
    let out = '';
    const timer = setTimeout(() => p.kill('SIGKILL'), timeoutMs || 5000);
    p.stdout.on('data', (d) => { out += d.toString(); });
    p.on('close', () => {
      clearTimeout(timer);
      const sec = parseFloat(out.trim());
      resolve(Number.isFinite(sec) && sec > 0 ? Math.round(sec * 1000) : null);
    });
    p.on('error', () => { clearTimeout(timer); resolve(null); });
  });
  return probe(['-select_streams', 'a:0', '-show_entries', 'stream=duration'])
    .then((ms) => ms || probe(['-show_entries', 'format=duration']));
}

// Linearly rescale all SRT cue times from [0, srtEnd] to
// [leadInMs, durationMs - tailPadMs]. Pure; returns the input unchanged on
// any guard failure. Factor bounds reject SRT/video gross mismatches; a 5%
// passthrough skips needless rewrites when the estimate already fits.
function rescaleSrtToDuration(srt, durationMs, opts) {
  try {
    const o = opts || {};
    let leadInMs = Number.isFinite(o.leadInMs) && o.leadInMs >= 0
      ? o.leadInMs : 0;
    let tailPadMs = Number.isFinite(o.tailPadMs) && o.tailPadMs >= 0
      ? o.tailPadMs : 300;
    const minFactor = o.minFactor || 0.5;
    const maxFactor = o.maxFactor || 3;
    if (!Number.isFinite(durationMs) || durationMs <= 1000) return srt;
    if (leadInMs + tailPadMs >= durationMs) { leadInMs = 0; tailPadMs = 0; }
    let srtEndMs = 0;
    let matched = false;
    srt.replace(SRT_TIME_RE, (all, h1, m1, s1, x1, h2, m2, s2, x2) => {
      matched = true;
      srtEndMs = Math.max(srtEndMs, srtTimeToMs(h2, m2, s2, x2));
      return all;
    });
    if (!matched || srtEndMs <= 0) return srt;
    if (leadInMs === 0 && Math.abs(srtEndMs - durationMs) / durationMs <= 0.05) {
      return srt;
    }
    const factor = (durationMs - leadInMs - tailPadMs) / srtEndMs;
    if (!(factor >= minFactor && factor <= maxFactor)) return srt;
    return srt.replace(SRT_TIME_RE, (all, h1, m1, s1, x1, h2, m2, s2, x2) => {
      const start = leadInMs + Math.round(srtTimeToMs(h1, m1, s1, x1) * factor);
      let end = leadInMs + Math.round(srtTimeToMs(h2, m2, s2, x2) * factor);
      if (end < start + 300) end = start + 300; // anti-flicker floor
      return msToSrtTime(start) + ' --> ' + msToSrtTime(end);
    });
  } catch (e) {
    return srt;
  }
}

function sendJson(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(obj));
}

const server = http.createServer(async (req, res) => {
  const urlPath = req.url.split('?')[0];
  try {
    if (req.method === 'GET' && urlPath === '/healthz') {
      res.writeHead(200);
      return res.end('ok');
    }

    if (req.method === 'GET' && urlPath.startsWith('/file/')) {
      const name = path.basename(urlPath);
      const filePath = path.join(OUT_DIR, name);
      if (!filePath.startsWith(OUT_DIR) || !fs.existsSync(filePath)) {
        res.writeHead(404);
        return res.end('not found');
      }
      res.writeHead(200, { 'Content-Type': 'video/mp4' });
      return fs.createReadStream(filePath).pipe(res);
    }

    if (req.method === 'POST' && urlPath === '/burn') {
      if (!authed(req)) {
        res.writeHead(401);
        return res.end('unauthorized');
      }
      const body = JSON.parse(await readBody(req));
      const videoUrl = body.videoUrl || body.mp4Url;
      const srt = String(body.srt || '');
      const forceStyle = String(body.forceStyle || '');
      if (!videoUrl || !srt.trim()) {
        return sendJson(res, 400, { error: 'missing videoUrl or srt' });
      }

      const id = crypto.randomBytes(12).toString('hex');
      const inMp4 = path.join(os.tmpdir(), id + '-in.mp4');
      const srtFile = path.join(os.tmpdir(), id + '.srt');
      const outMp4 = path.join(OUT_DIR, id + '.mp4');
      await download(videoUrl, inMp4);

      // stretchToVideo: default ON (opt out with explicit false), so payloads
      // from older edge versions (no field) get the desync fix immediately.
      // The 5% passthrough + factor bounds inside rescaleSrtToDuration keep
      // well-timed or grossly-mismatched SRTs untouched.
      let finalSrt = srt;
      if (body.stretchToVideo !== false) {
        const durationMs = await ffprobeDurationMs(inMp4, 5000);
        if (durationMs) {
          finalSrt = rescaleSrtToDuration(srt, durationMs, {
            leadInMs: Number(body.leadInMs),
            tailPadMs: Number(body.tailPadMs),
          });
          if (finalSrt !== srt) {
            console.log(
              '[burn] srt rescaled to media duration ' + durationMs + 'ms',
            );
          }
        }
      }
      fs.writeFileSync(srtFile, finalSrt, 'utf8');

      const vf = buildVideoFilter(
        srtFile,
        forceStyle,
        resolutionHeight(body.resolution),
      );
      const args = [
        '-y',
        '-i', inMp4,
        '-vf', vf,
        '-c:a', 'copy',
        '-movflags', '+faststart',
        outMp4,
      ];
      const ff = spawn('ffmpeg', args, { stdio: ['ignore', 'ignore', 'pipe'] });
      let errTail = '';
      ff.stderr.on('data', (d) => {
        errTail = (errTail + d.toString()).slice(-4000);
      });
      const code = await new Promise((resolve) => ff.on('close', resolve));
      fs.unlink(inMp4, () => {});
      fs.unlink(srtFile, () => {});
      if (code !== 0 || !fs.existsSync(outMp4)) {
        return sendJson(res, 500, {
          error: 'ffmpeg failed',
          detail: errTail.slice(-500),
        });
      }
      setTimeout(() => fs.unlink(outMp4, () => {}), FILE_TTL_MS);

      const base = PUBLIC_BASE_URL || 'https://' + req.headers.host;
      return sendJson(res, 200, { url: base + '/file/' + id + '.mp4' });
    }

    res.writeHead(404);
    res.end('not found');
  } catch (error) {
    sendJson(res, 500, { error: String((error && error.message) || error) });
  }
});

if (require.main === module) {
  server.listen(PORT, () => {
    console.log('caption-transcoder listening on ' + PORT);
  });
}

// Exported for unit tests (test.js). The server only listens when run directly.
module.exports = {
  buildVideoFilter,
  resolutionHeight,
  authed,
  srtTimeToMs,
  msToSrtTime,
  rescaleSrtToDuration,
};
