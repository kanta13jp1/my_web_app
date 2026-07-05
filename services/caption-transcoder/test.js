'use strict';
// Black-box unit tests for the pure helpers (no ffmpeg / network needed).
// Run: node test.js
const assert = require('assert');
const {
  buildVideoFilter,
  resolutionHeight,
  authed,
  srtTimeToMs,
  msToSrtTime,
  rescaleSrtToDuration,
} = require('./server.js');

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
ok('subtitles filename quoted', fs1.includes("subtitles='/tmp/x.srt'"));
ok('force_style single-quoted', fs1.includes(":force_style='FontName=Noto Sans CJK JP,FontSize=22'"));
// Windows パス: ドライブコロンを \: へエスケープした上で引用符に包む
// (未対応だと ffmpeg がコロンでフィルタオプション分割して失敗する)。
const fsWin = buildVideoFilter('C:\\Users\\me\\a.srt', '', null);
ok('windows path quoted+escaped', fsWin.includes("subtitles='C\\:/Users/me/a.srt'"));

const fs2 = buildVideoFilter('/tmp/x.srt', '', null);
ok('no scale when height null', !fs2.includes('scale='));
ok('no force_style when empty', !fs2.includes('force_style'));

// authed: with no API_KEY configured, everything is allowed (env-driven; here unset).
ok('auth open when no key', authed({ headers: {} }) === true);

// --- SRT time conversion ----------------------------------------------------
ok('srtTimeToMs basic', srtTimeToMs('00', '01', '02', '345') === 62345);
ok('msToSrtTime basic', msToSrtTime(62345) === '00:01:02,345');
ok('msToSrtTime clamps negative', msToSrtTime(-5) === '00:00:00,000');
ok('roundtrip', msToSrtTime(srtTimeToMs('01', '02', '03', '004')) === '01:02:03,004');

// --- rescaleSrtToDuration ----------------------------------------------------
// 2 cues: 0-10s, 10-20s (estimated). Real duration 10s -> factor (10000-300)/20000 = 0.485
// which is below minFactor 0.5 -> unchanged. Use duration 12s: factor (12000-300)/20000=0.585.
const SRT2 =
  '1\n00:00:00,000 --> 00:00:10,000\nline one\n\n' +
  '2\n00:00:10,000 --> 00:00:20,000\nline two\n';

const scaled = rescaleSrtToDuration(SRT2, 12000, {});
ok('rescale changes timings', scaled !== SRT2);
ok('rescale first cue start stays 0', scaled.includes('00:00:00,000 --> '));
// factor = 11700/20000 = 0.585 -> cue1 end = 5850ms, cue2 end = 11700ms
ok('rescale cue1 end 5850', scaled.includes('00:00:05,850'));
ok('rescale last cue ends at duration-tailPad', scaled.includes('00:00:11,700'));

// passthrough within 5%: duration 20500 vs srt end 20000 -> unchanged.
ok('5% passthrough', rescaleSrtToDuration(SRT2, 20500, {}) === SRT2);

// factor bounds: absurd duration (srt 20s -> video 90s = factor 4.5 > 3) -> unchanged.
ok('factor upper bound', rescaleSrtToDuration(SRT2, 90000, {}) === SRT2);
// too-short duration -> unchanged.
ok('duration <= 1s unchanged', rescaleSrtToDuration(SRT2, 900, {}) === SRT2);

// leadInMs shifts starts: lead 1000, duration 12000 -> factor (12000-1000-300)/20000=0.535
const led = rescaleSrtToDuration(SRT2, 12000, { leadInMs: 1000 });
ok('leadIn shifts first start', led.includes('00:00:01,000 --> '));

// invalid srt (no cues) -> unchanged.
ok('no-cue srt unchanged', rescaleSrtToDuration('junk text', 12000, {}) === 'junk text');

// anti-flicker floor: tiny cue stays >= 300ms after rescale.
const TINY =
  '1\n00:00:00,000 --> 00:00:00,200\nblip\n\n' +
  '2\n00:00:00,200 --> 00:00:20,000\nrest\n';
const tinyScaled = rescaleSrtToDuration(TINY, 12000, {});
const firstCue = /00:00:00,000 --> 00:00:00,(\d{3})/.exec(tinyScaled);
ok('anti-flicker floor >= 300ms', firstCue !== null && Number(firstCue[1]) >= 300);

console.log('caption-transcoder tests passed: ' + passed);
