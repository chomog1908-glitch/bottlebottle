"""효과음 4종을 직접 합성해 assets/audio/에 WAV로 저장한다.

외부 음원을 받아 쓰지 않는 이유:
  - 라이선스를 따질 필요가 없다
  - 파일이 작다 (전부 합쳐 200KB 남짓)
  - 소리를 고치고 싶으면 이 파일의 숫자만 바꾸면 된다

표준 라이브러리만 쓴다. 다시 만들려면:  python tool/make_sounds.py
"""

import math
import os
import random
import struct
import wave

RATE = 22050  # 짧은 효과음에는 이 정도면 충분하다. 파일이 절반으로 준다.
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write_wav(name, samples):
    """-1.0~1.0 범위의 실수 목록을 16비트 모노 WAV로 저장한다."""
    path = os.path.join(OUT_DIR, name)
    peak = max(1e-9, max(abs(s) for s in samples))
    # 최대치를 0.9로 맞춘다. 1.0에 붙이면 기기에 따라 지직거린다.
    gain = 0.9 / peak
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(f"{name}  {len(samples) / RATE:.2f}s  {len(frames) / 1024:.0f}KB")


def envelope(i, total, attack=0.01, release=0.3):
    """소리의 시작과 끝을 부드럽게 깎는다.

    이걸 안 하면 파형이 갑자기 끊겨 '틱' 하는 잡음이 난다.
    """
    t = i / total
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (1.0 - t) / release) if release > 0 else 1.0
    return a * r


def make_pick():
    """병을 집는 소리. 짧게 올라가는 물방울 소리."""
    dur = 0.10
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        # 주파수가 올라가면 '집어 올린다'는 느낌이 난다.
        freq = 620 + 520 * (t / dur)
        s = math.sin(2 * math.pi * freq * t)
        out.append(s * math.exp(-14 * t) * envelope(i, n, 0.02, 0.2))
    return out


def make_pour():
    """쪼르륵. 붓는 동안 반복 재생하다가 다 부으면 멈춘다.

    붓는 양에 따라 소리 길이가 달라지도록, 넉넉히 길게 만들어 두고
    앱에서 필요한 만큼만 재생한 뒤 멈추는 방식을 쓴다.
    """
    dur = 2.4
    n = int(RATE * dur)
    out = [0.0] * n

    # 1) 바탕이 되는 물줄기 소리. 잡음을 완만하게 걸러 '쏴' 하는 흐름을 만든다.
    prev = 0.0
    for i in range(n):
        white = random.uniform(-1, 1)
        # 간단한 저역 통과 필터. 높은 소리를 깎아내면 물소리처럼 들린다.
        prev = prev * 0.85 + white * 0.15
        out[i] += prev * 0.35

    # 2) 그 위에 물방울(기포)을 흩뿌린다. 이게 '쪼르륵'의 정체다.
    rng = random.Random(20260815)
    t = 0.0
    while t < dur - 0.05:
        start = int(t * RATE)
        freq = rng.uniform(360, 1000)
        # 기포는 소리가 나면서 음이 살짝 올라간다. 실제 물방울이 그렇다.
        rise = rng.uniform(1.2, 2.2)
        length = int(RATE * rng.uniform(0.015, 0.045))
        amp = rng.uniform(0.25, 0.6)
        for k in range(length):
            if start + k >= n:
                break
            tt = k / RATE
            f = freq * (1 + rise * tt * 8)
            out[start + k] += (
                math.sin(2 * math.pi * f * tt) * amp * math.exp(-38 * tt)
            )
        t += rng.uniform(0.02, 0.06)

    # 시작과 끝을 부드럽게. 중간에 멈춰도 되도록 끝의 페이드는 짧게 둔다.
    for i in range(n):
        out[i] *= envelope(i, n, 0.015, 0.05)
    return out


def make_clear():
    """한 판을 다 맞췄을 때. 짧고 밝은 아르페지오."""
    # 도-미-솔-도. 흔하지만 그래서 바로 '해냈다'로 읽힌다.
    notes = [523.25, 659.25, 783.99, 1046.50]
    step = 0.085
    dur = step * len(notes) + 0.45
    n = int(RATE * dur)
    out = [0.0] * n

    for idx, freq in enumerate(notes):
        start = int(idx * step * RATE)
        for k in range(n - start):
            tt = k / RATE
            # 배음을 살짝 섞으면 삐 소리가 아니라 악기 소리에 가까워진다.
            s = (
                math.sin(2 * math.pi * freq * tt)
                + 0.35 * math.sin(2 * math.pi * freq * 2 * tt)
                + 0.15 * math.sin(2 * math.pi * freq * 3 * tt)
            )
            out[start + k] += s * math.exp(-5.0 * tt) * 0.34

    for i in range(n):
        out[i] *= envelope(i, n, 0.005, 0.25)
    return out


def make_wrong():
    """부을 수 없는 곳에 부으려 했을 때. 낮고 짧은 '툭'.

    일부러 순하게 만든다. 실수를 나무라는 소리가 되면 안 된다.
    """
    dur = 0.16
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        freq = 210 - 70 * (t / dur)
        s = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(2 * math.pi * freq * 1.5 * t)
        out.append(s * math.exp(-16 * t) * envelope(i, n, 0.01, 0.3))
    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav("pick.wav", make_pick())
    write_wav("pour.wav", make_pour())
    write_wav("clear.wav", make_clear())
    write_wav("wrong.wav", make_wrong())


if __name__ == "__main__":
    main()
