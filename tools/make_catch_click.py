"""포획 순간 "착" 소리 합성 (기획서 5장, v0.54).

볼이 잠기는 느낌: 짧고 높은 딸깍(1) → 35ms 뒤 더 크고 낮은 딸깍(2) + 낮은 "툭" 울림.
실행: python tools/make_catch_click.py  → Assets/Audio/SFX/PokemonBallCatch.wav (44.1kHz, 16bit, 스테레오, 약 0.18초)
"""
import math
import random
import struct
import wave

RATE = 44100
LENGTH = 0.18
OUT = 'Assets/Audio/SFX/PokemonBallCatch.wav'


def click(t, start, noise_amp, noise_tau, tone_hz, tone_amp, tone_tau, thump_amp=0.0, thump_tau=0.03, rng=None):
    x = t - start
    if x < 0:
        return 0.0
    v = noise_amp * rng.uniform(-1, 1) * math.exp(-x / noise_tau)
    v += tone_amp * math.sin(2 * math.pi * tone_hz * x) * math.exp(-x / tone_tau)
    if thump_amp:
        # 낮은 울림: 주파수가 살짝 내려가는 사인
        f = 190.0 - 60.0 * min(1.0, x / 0.05)
        v += thump_amp * math.sin(2 * math.pi * f * x) * math.exp(-x / thump_tau)
    return v


def main():
    rng = random.Random(7)
    n = int(RATE * LENGTH)
    samples = []
    prev = 0.0
    for i in range(n):
        t = i / RATE
        v = click(t, 0.000, 0.55, 0.0012, 3300, 0.35, 0.006, rng=rng)
        v += click(t, 0.035, 0.85, 0.0018, 1900, 0.55, 0.014, thump_amp=0.6, thump_tau=0.03, rng=rng)
        # 아주 약한 저역 통과로 날카로운 지글거림만 살짝 줄임
        v = prev + (v - prev) * 0.75
        prev = v
        samples.append(v)
    peak = max(abs(s) for s in samples) or 1.0
    gain = 0.7 / peak   # 약 -3dB
    # 끝 5ms 페이드아웃
    fade = int(RATE * 0.005)
    w = wave.open(OUT, 'wb')
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(RATE)
    frames = bytearray()
    for i, s in enumerate(samples):
        if i > n - fade:
            s *= (n - i) / fade
        v = int(max(-1.0, min(1.0, s * gain)) * 32767)
        frames += struct.pack('<hh', v, v)
    w.writeframes(bytes(frames))
    w.close()
    print('포획 "착" 소리 →', OUT)


if __name__ == '__main__':
    main()
