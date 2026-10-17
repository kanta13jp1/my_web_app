"""Original procedural audio for Echo Pump. No recordings or external samples."""
from pathlib import Path
import array
import hashlib
import json
import math
import random
import sys
import wave

RATE = 22050
TAU = math.tau


def write(path, samples):
    pcm = array.array('h', [round(max(-0.88, min(0.88, s)) * 32767) for s in samples])
    with wave.open(str(path), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(pcm.tobytes())
    peak = max(abs(s) for s in pcm) / 32767
    rms = math.sqrt(sum((s / 32767) ** 2 for s in pcm) / len(pcm))
    assert 0.005 < rms < 0.4 and peak < 0.89
    return {'seconds': len(pcm) / RATE, 'peak': peak, 'rms': rms,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def bgm():
    # All drone frequencies complete whole cycles in this 16 second loop.
    notes = [220, 261.625, 246.942, 164.814, 220, 293.665, 246.942, 207.652]
    for i in range(RATE * 16):
        t = i / RATE
        drone = (0.085 * math.sin(TAU * 55 * t)
                 + 0.045 * math.sin(TAU * 82.5 * t)
                 + 0.025 * math.sin(TAU * 110 * t))
        pulse = 0.75 + 0.25 * math.sin(TAU * t / 8)
        phase = t % 2
        envelope = math.sin(math.pi * phase / 2) ** 2 * math.exp(-phase * 2)
        bell = 0.13 * envelope * math.sin(TAU * notes[int(t // 2)] * phase)
        # Gentle boundary ramp on the complete mix prevents a loop click.
        fade = min(1, t / 0.04, (16 - t) / 0.04)
        yield fade * (drone * pulse + bell)


def effect(name, duration, freq, end_freq, noise, seed):
    rng = random.Random(seed)
    filtered = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        p = t / duration
        filtered = filtered * 0.55 + rng.uniform(-1, 1) * 0.45
        attack = min(1, t / 0.012)
        env = attack * (1 - p) ** 2
        tone = math.sin(TAU * (freq * t + (end_freq - freq) * t * t / (2 * duration)))
        if name in ('escape', 'start', 'collect', 'repair'):
            tone += 0.35 * math.sin(TAU * freq * 1.5 * t)
        if name in ('step', 'seal', 'damage', 'fail'):
            env *= 0.65 + 0.35 * math.cos(TAU * 12 * t)
        yield env * (0.38 * tone + noise * filtered)


def main():
    root = Path(__file__).resolve().parents[1] / 'assets/echo_pump'
    if '--check' in sys.argv:
        catalog = json.loads((root / 'AUDIO_PROVENANCE.json').read_text(encoding='utf-8'))
        assert len(catalog['files']) == 11
        for name, info in catalog['files'].items():
            path = root / name
            assert hashlib.sha256(path.read_bytes()).hexdigest() == info['sha256']
            with wave.open(str(path), 'rb') as source:
                assert (source.getnchannels(), source.getsampwidth(), source.getframerate()) == (1, 2, RATE)
                assert abs(source.getnframes() / RATE - info['seconds']) < 1 / RATE
                assert source.getnframes() > 0
        print('Verified 11 WAV headers, durations, and provenance hashes')
        return
    root.mkdir(parents=True, exist_ok=True)
    catalog = {'format': 'PCM WAV, mono, 22050Hz, 16bit',
               'origin': 'Original mathematical synthesis; no third-party samples', 'files': {}}
    catalog['files']['bgm.wav'] = write(root / 'bgm.wav', bgm())
    specs = [
        ('start', .55, 220, 330, .06),
        ('step', .24, 90, 48, .42),
        ('power', .34, 180, 75, .24),
        ('collect', .46, 523, 659, .02),
        ('repair', .65, 330, 440, .15),
        ('seal', .55, 130, 42, .50),
        ('drain', .95, 68, 125, .30),
        ('damage', .42, 150, 58, .48),
        ('escape', 1.25, 330, 660, .01),
        ('fail', 1.15, 130, 42, .12),
    ]
    for seed, (name, dur, freq, end, noise) in enumerate(specs):
        catalog['files'][name + '.wav'] = write(root / (name + '.wav'), effect(name, dur, freq, end, noise, seed))
    (root / 'AUDIO_PROVENANCE.json').write_text(json.dumps(catalog, indent=2), encoding='utf-8')
    print(f'Generated and checked {len(catalog["files"])} original WAV files')


if __name__ == '__main__':
    main()
