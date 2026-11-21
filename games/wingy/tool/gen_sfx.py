#!/usr/bin/env python3
"""Synthesizes the Wingy sound effects as 16-bit mono WAV (stdlib only, original sounds)."""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")


def tone(freqs, dur, vol=0.5, sweep=0.0, noise=0.0, decay=5.0, seed=1):
    rnd = random.Random(seed)
    n = int(RATE * dur)
    out, phase = [], [0.0] * len(freqs)
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t / dur) * min(1.0, i / 120)
        s = 0.0
        for k, f in enumerate(freqs):
            phase[k] += 2 * math.pi * f * (1 + sweep * t / dur) / RATE
            s += math.sin(phase[k])
        s = s / len(freqs) + noise * (rnd.random() * 2 - 1)
        out.append(max(-1, min(1, s * env * vol)))
    return out


def seq(*parts):
    r = []
    for p in parts:
        r += p
    return r


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in samples))


def main():
    save("flap", tone([300], 0.09, 0.35, sweep=1.2, noise=0.15, decay=6))
    save("pass", tone([660], 0.12, 0.4, decay=5))
    for i in range(1, 8):  # perfect chime rises per streak step
        f = 523.25 * (2 ** ((i - 1) * 2 / 12))
        save(f"perfect_{i}", seq(tone([f, f * 2], 0.1, 0.4), tone([f * 1.5, f * 3], 0.18, 0.4, decay=6)))
    save("orb", seq(tone([880], 0.06, 0.4), tone([1320], 0.12, 0.4, decay=6)))
    save("dash", tone([180], 0.5, 0.45, sweep=3.0, noise=0.5, decay=2.5))
    save("shatter", tone([1400, 2100], 0.28, 0.4, sweep=-0.5, noise=0.9, decay=7))
    save("hit", tone([140], 0.25, 0.6, sweep=-0.6, noise=0.5, decay=7))
    save("game_over", seq(tone([392], 0.18, 0.4), tone([330], 0.18, 0.4), tone([262], 0.4, 0.4, decay=4)))
    save("button", tone([740], 0.05, 0.3, decay=6))


if __name__ == "__main__":
    main()
