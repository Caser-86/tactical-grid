#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成程序化占位音效，保证 AudioManager 的 terrain/weapon 映射有文件可加载。
后续应被真实录音或 AI 生成音效替换。
"""

import math
import os
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "client" / "assets" / "audio" / "sfx"

SAMPLE_RATE = 22050
DURATION = 0.15


def save_wave(path: Path, samples: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(samples)


def white_noise(duration: float, amplitude: float = 0.3) -> bytes:
    import random
    n = int(SAMPLE_RATE * duration)
    data = []
    for _ in range(n):
        v = int((random.random() * 2 - 1) * amplitude * 32767)
        data.append(v)
    return struct.pack("<%dh" % n, *data)


def sine_wave(freq: float, duration: float, amplitude: float = 0.4) -> bytes:
    n = int(SAMPLE_RATE * duration)
    data = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = 1.0 - t / duration
        v = int(math.sin(2 * math.pi * freq * t) * amplitude * env * 32767)
        data.append(v)
    return struct.pack("<%dh" % n, *data)


def pulse_wave(freq: float, duration: float, duty: float = 0.3, amplitude: float = 0.3) -> bytes:
    n = int(SAMPLE_RATE * duration)
    data = []
    period = SAMPLE_RATE / freq
    for i in range(n):
        t = i / SAMPLE_RATE
        env = 1.0 - t / duration
        phase = (i % int(period)) / period
        v = int((1.0 if phase < duty else -1.0) * amplitude * env * 32767)
        data.append(v)
    return struct.pack("<%dh" % n, *data)


SOUNDS = {
    "sfx_step_road.wav": lambda: white_noise(0.08, 0.25),
    "sfx_step_grass.wav": lambda: white_noise(0.12, 0.15),
    "sfx_step_sand.wav": lambda: white_noise(0.10, 0.12),
    "sfx_step_water.wav": lambda: sine_wave(600, 0.18, 0.2),
    "sfx_step_snow.wav": lambda: white_noise(0.14, 0.08),
    "sfx_step_metal.wav": lambda: pulse_wave(800, 0.06, 0.2, 0.25),
    "sfx_step_rock.wav": lambda: white_noise(0.09, 0.2),
    "sfx_step_ground.wav": lambda: white_noise(0.10, 0.15),
    "sfx_hit_water.wav": lambda: sine_wave(300, 0.18, 0.25),
    "sfx_hit_metal.wav": lambda: pulse_wave(1200, 0.1, 0.15, 0.3),
    "sfx_hit_wood.wav": lambda: white_noise(0.1, 0.2),
    "sfx_hit_rock.wav": lambda: white_noise(0.08, 0.25),
    "sfx_combat_melee.wav": lambda: pulse_wave(400, 0.08, 0.1, 0.25),
    "sfx_combat_laser.wav": lambda: sine_wave(1500, 0.12, 0.15),
}


def main():
    for name, gen in SOUNDS.items():
        path = OUT / name
        if path.exists():
            print(f"已存在，跳过: {name}")
            continue
        samples = gen()
        save_wave(path, samples)
        print(f"生成: {name} ({len(samples)} bytes)")
    print(f"\n占位音效已生成到: {OUT}")


if __name__ == "__main__":
    main()
