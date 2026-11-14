#!/usr/bin/env python3
"""Makes the four shop ambience loops (rain, waves, forest_wind, fireplace) from synthesised
noise: original sound, no samples, no third-party source. Mono, 44.1 kHz, 64 kbps MP3, 24 s,
seamless (all filtering is circular, all envelopes are periodic).

Needs: pip install numpy lameenc
Usage: python3 scripts/make_ambience.py <output dir>   (e.g. a game's assets/ambience)
Fixed random seeds: the output is reproducible.
"""
import sys
from pathlib import Path

import numpy as np

SR = 44100
SECONDS = 24
N = SR * SECONDS
T = np.arange(N) / SR


def noise(rng):
    return rng.standard_normal(N)


def band(x, lo, hi):
    """Circular band-pass by FFT (keeps the loop seamless)."""
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(N, 1 / SR)
    mask = np.ones_like(fr)
    mask[fr < lo] = 0
    mask[fr > hi] = 0
    # soft edges
    return np.fft.irfft(f * mask, N)


def slow(rng, cycles, depth):
    """Periodic slow modulation: sum of a few whole-cycle sines over the loop."""
    m = np.zeros(N)
    for k in cycles:
        m += rng.uniform(.5, 1) * np.sin(2 * np.pi * k * T / SECONDS + rng.uniform(0, 6.28))
    m /= max(1e-9, np.abs(m).max())
    return 1 - depth + depth * (m * .5 + .5)


def norm(x, peak=.8):
    return x / max(1e-9, np.abs(x).max()) * peak


def circ_add(buf, start, grain):
    idx = (start + np.arange(len(grain))) % N
    buf[idx] += grain


def rain(rng):
    hiss = band(noise(rng), 1500, 9000)
    body = band(noise(rng), 400, 1800) * .5
    drops = np.zeros(N)
    for _ in range(SECONDS * 90):
        n = int(rng.uniform(.002, .006) * SR)
        g = rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 4)) * rng.uniform(.2, 1)
        circ_add(drops, rng.integers(0, N), band_small(g))
    return norm(hiss * slow(rng, [1, 2], .15) + body + drops * hiss.std() * 3)


def band_small(g):
    # crude high-pass on a short grain
    return g - np.convolve(g, np.ones(8) / 8, mode="same")


def waves(rng):
    base = band(noise(rng), 80, 3500)
    period = SECONDS / 3  # three swells per loop
    ph = 2 * np.pi * T / period
    swell = (np.sin(ph - 1.2) * .5 + .5) ** 1.8
    foam = band(noise(rng), 2000, 8000) * (np.sin(ph - .6) * .5 + .5) ** 3
    wob = slow(rng, [5, 7], .2)
    return norm((base * (.15 + .85 * swell) + foam * .5) * wob)


def forest_wind(rng):
    w = band(noise(rng), 120, 1400)
    gust = slow(rng, [1, 3, 4], .8)
    hi = band(noise(rng), 1500, 5000) * .25 * slow(rng, [2, 5], .9)
    low = band(noise(rng), 40, 200) * .5
    return norm(w * gust + hi + low)


def fireplace(rng):
    rumble = band(noise(rng), 50, 400) * .35 * slow(rng, [3, 6], .4)
    hiss = band(noise(rng), 3000, 9000) * .12 * slow(rng, [4, 9], .5)
    crackle = np.zeros(N)
    for _ in range(SECONDS * 14):
        n = int(rng.uniform(.0015, .012) * SR)
        g = rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 5))
        amp = rng.uniform(.15, 1) ** 2
        circ_add(crackle, rng.integers(0, N), band_small(g) * amp)
    return norm(rumble + hiss + crackle * rumble.std() * 5)


LOOPS = {"rain": rain, "waves": waves, "forest_wind": forest_wind, "fireplace": fireplace}


def encode(x, path):
    import lameenc

    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    enc = lameenc.Encoder()
    enc.set_bit_rate(64)
    enc.set_in_sample_rate(SR)
    enc.set_channels(1)
    enc.set_quality(2)
    path.write_bytes(bytes(enc.encode(pcm) + enc.flush()))


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for i, (name, fn) in enumerate(LOOPS.items()):
        encode(fn(np.random.default_rng(1000 + i)), out / f"{name}.mp3")
        print("wrote", out / f"{name}.mp3")


if __name__ == "__main__":
    main()
