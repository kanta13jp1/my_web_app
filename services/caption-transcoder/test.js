'use strict';
// Black-box unit tests for the pure helpers (no ffmpeg / network needed).
// Run: node test.js
const assert = require('assert');
const { buildVideoFilter, resolutionHeight, authed } = require('./server.js');

let passed = 0;
function ok(name, cond) {
  assert.ok(cond, name);
  passed += 1;
}

// resolutionHeight: parses "540p" -> 540, ignores junk.
ok('540p -> 540', resolutionHeight('540p') === 540);
ok('1080p -> 1080', resolutionHeight('1080p') === 1080);
ok('empty -> null', resolutionHeight('') === null);
ok('garbage -> null', resolutionHeight('abc') === null);

// buildVideoFilter: force_style single-quoted so its commas are literal; scale prefixed.
const fs1 = buildVideoFilter('/tmp/x.srt', 'FontName=Noto Sans CJK JP,FontSize=22', 540);
ok('scale prefixed', fs1.startsWith('scale=-2:540,'));
ok('subtitles present', fs1.includes('subtitles=/tmp/x.srt'));
ok('force_style single-quoted', fs1.includes(":force_style='FontName=Noto Sans CJK JP,FontSize=22'"));

const fs2 = buildVideoFilter('/tmp/x.srt', '', null);
ok('no scale when height null', !fs2.includes('scale='));
ok('no force_style when empty', !fs2.includes('force_style'));

// authed: with no API_KEY configured, everything is allowed (env-driven; here unset).
ok('auth open when no key', authed({ headers: {} }) === true);

console.log('caption-transcoder tests passed: ' + passed);
