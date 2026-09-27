#!/usr/bin/env python3
"""Makes Larder's sound effects from scratch, so they're all original.

    python3 Tools/sounds/make_sounds.py

Each sound is built from simple tones (a sine plus a few overtones, shaped by
a quick attack and a decay) and written as a 16-bit mono WAV into its data
set in the app's asset catalog. Everyday sounds are short and quiet; the
celebrations are longer, brighter and louder.
"""

import json
import math
import os
import random
import struct
import wave

RATE = 44100
ASSETS = os.path.join(os.path.dirname(__file__), "..", "..", "Larder", "Larder", "Assets.xcassets")

# Note frequencies, in Hz.
C5, D5, E5, F5, G5, A5, B5 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 987.77
C6, D6, E6, G6, C7 = 1046.5, 1174.66, 1318.51, 1567.98, 2093.0


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(into, sound, at):
    """Adds `sound` into `into`, starting `at` seconds in, growing it if needed."""
    start = int(RATE * at)
    end = start + len(sound)
    if end > len(into):
        into.extend([0.0] * (end - len(into)))
    for i, value in enumerate(sound):
        into[start + i] += value
    return into


def tone(freq, seconds, amp=1.0, attack=0.004, decay=6.0, partials=((1, 1.0),), glide_to=None):
    """A tone with a quick attack and an exponential decay. `partials` are
    (multiple, loudness) overtones; `glide_to` slides the pitch."""
    out = []
    phases = [0.0] * len(partials)
    n = int(RATE * seconds)
    for i in range(n):
        t = i / RATE
        f = freq if glide_to is None else freq + (glide_to - freq) * (i / n)
        envelope = min(1.0, t / attack) * math.exp(-decay * t)
        value = 0.0
        for k, (multiple, loudness) in enumerate(partials):
            phases[k] += 2 * math.pi * f * multiple / RATE
            value += loudness * math.sin(phases[k])
        out.append(amp * envelope * value)
    # A tiny fade at the very end, so nothing clicks.
    fade = min(len(out), int(RATE * 0.01))
    for i in range(fade):
        out[-1 - i] *= i / fade
    return out


BELL = ((1, 1.0), (2, 0.35), (3, 0.12), (4.2, 0.05))
SOFT = ((1, 1.0), (2, 0.15))


def normalise(samples, peak):
    top = max(1e-9, max(abs(s) for s in samples))
    return [s / top * peak for s in samples]


def write(name, samples, peak):
    samples = normalise(samples, peak)
    folder = os.path.join(ASSETS, f"{name}.dataset")
    os.makedirs(folder, exist_ok=True)
    filename = f"{name.lower()}.wav"
    with wave.open(os.path.join(folder, filename), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    contents = {
        "data": [{"filename": filename, "idiom": "universal",
                  "universal-type-identifier": "com.microsoft.waveform-audio"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"wrote {name}: {len(samples) / RATE:.2f} s")


def arpeggio(notes, gap, length, decay, partials=BELL):
    out = []
    for i, note in enumerate(notes):
        mix(out, tone(note, length, decay=decay, partials=partials), i * gap)
    return out


def sparkle(count, start, spread, seed):
    """A scatter of tiny high pings, like light catching glitter."""
    rng = random.Random(seed)
    out = []
    for _ in range(count):
        note = rng.choice([C7, G6, E6, 2637.0, 3136.0])
        mix(out, tone(note, 0.18, amp=rng.uniform(0.15, 0.3), decay=22, partials=SOFT), start + rng.uniform(0, spread))
    return out


def main():
    # Everyday: soft and short. The tap is barely there, on purpose.
    write("Tap", tone(1400, 0.03, decay=140, partials=SOFT), peak=0.12)
    pop = tone(420, 0.07, decay=45, partials=SOFT, glide_to=900)
    write("Pop", mix(list(pop), tone(560, 0.07, decay=45, partials=SOFT, glide_to=1100), 0.08), peak=0.35)
    write("Send", tone(620, 0.09, decay=30, partials=SOFT, glide_to=1050), peak=0.25)
    write("Receive", mix(tone(E6, 0.12, decay=28, partials=SOFT), tone(G6, 0.14, decay=26, partials=SOFT), 0.07), peak=0.2)
    write("RecordStart", mix(tone(660, 0.08, decay=35, partials=SOFT), tone(990, 0.1, decay=30, partials=SOFT), 0.07),
          peak=0.25)
    write("RecordStop", mix(tone(990, 0.08, decay=35, partials=SOFT), tone(660, 0.1, decay=30, partials=SOFT), 0.07),
          peak=0.22)

    # A kitchen timer: three bright dings.
    ding = tone(1320, 0.34, decay=9, partials=BELL)
    timer = []
    for i in range(3):
        mix(timer, ding, i * 0.28)
    write("TimerDone", timer, peak=0.7)

    # Made it: a bright rising arpeggio landing on a ringing chord.
    made = arpeggio([C5, E5, G5, C6], gap=0.09, length=0.5, decay=5)
    for note in (C6, E6, G6):
        mix(made, tone(note, 0.9, amp=0.6, decay=3.2, partials=BELL), 0.36)
    mix(made, sparkle(8, 0.4, 0.5, seed=1), 0)
    write("MadeIt", made, peak=0.85)

    # The first meal ever: a swell for the haptic build-up (0.55 s), then
    # the biggest chord in the app, with glitter.
    first = tone(220, 0.55, amp=0.5, attack=0.5, decay=0.2, partials=SOFT, glide_to=660)
    for note in (C5, E5, G5, C6, E6, G6):
        mix(first, tone(note, 1.3, amp=0.7, decay=2.4, partials=BELL), 0.55)
    mix(first, sparkle(16, 0.6, 0.9, seed=2), 0)
    write("FirstMeal", first, peak=0.9)

    # Congrats (goals, streak milestones): cheerful three notes up.
    congrats = arpeggio([G5, B5, D6], gap=0.12, length=0.45, decay=6)
    mix(congrats, tone(G6, 0.6, amp=0.5, decay=4, partials=BELL), 0.36)
    write("Congrats", congrats, peak=0.75)

    # Unlock (a new look): an energetic sweep up, then a quick sparkle run.
    unlock = tone(300, 0.32, amp=0.6, attack=0.02, decay=1.5, partials=SOFT, glide_to=1500)
    mix(unlock, arpeggio([G6, C7, 2637.0, 3136.0], gap=0.06, length=0.3, decay=10, partials=SOFT), 0.3)
    mix(unlock, sparkle(8, 0.35, 0.5, seed=3), 0)
    write("Unlock", unlock, peak=0.8)

    # Welcome to Plus: a chord run up and a big, ringing finish.
    welcome = arpeggio([C5, E5, G5, C6, E6, G6], gap=0.08, length=0.5, decay=5)
    for note in (F5, A5, C6):
        mix(welcome, tone(note, 0.6, amp=0.55, decay=4, partials=BELL), 0.55)
    for note in (C5, G5, C6, E6, G6, C7):
        mix(welcome, tone(note, 1.4, amp=0.6, decay=2.2, partials=BELL), 0.85)
    mix(welcome, sparkle(20, 0.8, 1.0, seed=4), 0)
    write("PlusWelcome", welcome, peak=0.9)


if __name__ == "__main__":
    main()
