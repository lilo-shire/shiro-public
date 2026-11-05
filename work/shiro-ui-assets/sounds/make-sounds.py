#!/usr/bin/env python3
"""Synthesises Shiro's notification sounds: 3 packs x 4 events, 44.1 kHz mono 16-bit WAV.

Run:  python3 make-sounds.py            (writes WAVs next to this script)
"""
import math
import os
import struct
import wave

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))

# Each pack is a timbre: partial ratios, partial gains, attack and decay time constant, base octave shift.
PACKS = {
    'glass': {'partials': [1.0, 2.76, 5.40], 'gains': [1.0, 0.32, 0.10], 'attack': 0.003, 'decay': 0.85, 'octave': 0},
    'wood':  {'partials': [1.0, 3.93, 9.20], 'gains': [1.0, 0.22, 0.05], 'attack': 0.002, 'decay': 0.32, 'octave': -1},
    'air':   {'partials': [1.0, 2.00, 3.00], 'gains': [1.0, 0.14, 0.04], 'attack': 0.045, 'decay': 1.10, 'octave': -1},
}

C6, D6, E6, G6, A6, G5 = 1046.50, 1174.66, 1318.51, 1567.98, 1760.00, 783.99
# Each event: list of (start seconds, frequency, gain) notes and total length.
EVENTS = {
    'focus-end': {'notes': [(0.00, C6, 1.0), (0.15, E6, 0.9), (0.30, G6, 0.9)], 'length': 1.9},
    'break-end': {'notes': [(0.00, G5, 1.0), (0.18, C6, 1.0)], 'length': 1.6},
    'task-done': {'notes': [(0.00, E6, 0.8), (0.09, A6, 0.9)], 'length': 0.9},
    'start':     {'notes': [(0.00, D6, 0.6)], 'length': 0.5},
}


def render(pack, event):
    count = int(RATE * event['length'])
    out = [0.0] * count
    shift = 2 ** pack['octave']
    for start, freq, gain in event['notes']:
        first = int(start * RATE)
        for i in range(first, count):
            t = (i - first) / RATE
            env = min(1.0, t / pack['attack']) * math.exp(-t / pack['decay'])
            if env < 1e-4 and t > pack['attack']:
                break
            sample = 0.0
            for ratio, g in zip(pack['partials'], pack['gains']):
                # Higher partials die faster, like a struck object.
                sample += g * math.exp(-t * ratio * 0.9) * math.sin(2 * math.pi * freq * shift * ratio * t)
            out[i] += gain * env * sample
    peak = max(abs(x) for x in out) or 1.0
    scale = 0.70 / peak  # about -3 dBFS
    fade = int(0.03 * RATE)
    for i in range(fade):
        out[count - 1 - i] *= i / fade
    return [max(-1.0, min(1.0, x * scale)) for x in out]


def write(path, samples):
    with wave.open(path, 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h', int(s * 32767)) for s in samples))


if __name__ == '__main__':
    for pack_name, pack in PACKS.items():
        for event_name, event in EVENTS.items():
            path = os.path.join(HERE, f'{pack_name}-{event_name}.wav')
            write(path, render(pack, event))
            print(path)
