#!/usr/bin/env python3
"""Makes Larder's sound effects from scratch, so they're all original.

    python3 Tools/sounds/make_sounds.py

Every sound is built from a few simple voices: a wooden mallet (like a
marimba), a bell, and a puff of noise for clicks and swooshes. A small room
reverb goes on top so they don't sound like bare beeps. Each one is written
as a 16-bit mono WAV into its data set in the app's asset catalog. Everyday
sounds are short and quiet; the celebrations are longer, brighter and louder.

The timer alarm is also written as a plain file in Larder/Sounds, because a
notification can only play a sound that sits in the app bundle itself.
"""

import json
import math
import os
import random
import struct
import wave

RATE = 44100
HERE = os.path.dirname(__file__)
APP = os.path.join(HERE, "..", "..", "Larder", "Larder")
ASSETS = os.path.join(APP, "Assets.xcassets")
BUNDLED = os.path.join(APP, "Sounds")


def note(name):
    """Frequency of a note like "C5" or "F#4", in Hz."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave - 4)) / 12)


# MARK: - Building blocks

def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(into, sound, at=0.0, gain=1.0):
    """Adds `sound` into `into`, starting `at` seconds in, growing it if needed."""
    start = int(RATE * at)
    end = start + len(sound)
    if end > len(into):
        into.extend([0.0] * (end - len(into)))
    for i, value in enumerate(sound):
        into[start + i] += value * gain
    return into


def voice(freq, seconds, partials, amp=1.0, attack=0.003, glide_to=None, glide_time=None):
    """A pitched sound made of overtones. Each partial is (multiple, loudness,
    decay per second), so the bright top dies away faster than the body, the
    way a struck bar or bell does."""
    n = int(RATE * seconds)
    out = [0.0] * n
    glide_n = int(RATE * (glide_time or seconds))
    for multiple, loudness, decay in partials:
        phase = 0.0
        for i in range(n):
            t = i / RATE
            if glide_to is None:
                f = freq
            else:
                # An exponential slide sounds more natural than a straight one.
                k = min(1.0, i / max(1, glide_n))
                f = freq * (glide_to / freq) ** k
            phase += 2 * math.pi * f * multiple / RATE
            envelope = min(1.0, t / attack) * math.exp(-decay * t)
            out[i] += amp * loudness * envelope * math.sin(phase)
    fade(out, 0.008)
    return out


def mallet(freq, seconds=0.5, amp=1.0, decay=7.0):
    """A soft wooden bar, like a marimba."""
    return voice(freq, seconds, ((1, 1.0, decay), (3.93, 0.28, decay * 3.2), (9.2, 0.07, decay * 7)),
                 amp=amp, attack=0.002)


def bell(freq, seconds=1.2, amp=1.0, decay=3.0):
    """A small, bright bell. Two copies a hair apart in pitch make it shimmer."""
    partials = ((1, 1.0, decay), (2.0, 0.42, decay * 1.4), (3.0, 0.2, decay * 1.9),
                (4.2, 0.1, decay * 2.6), (5.4, 0.05, decay * 3.2))
    a = voice(freq, seconds, partials, amp=amp * 0.6, attack=0.002)
    b = voice(freq * 1.0025, seconds, partials, amp=amp * 0.4, attack=0.002)
    return mix(a, b)


def noise(seconds, amp=1.0, attack=0.001, decay=60.0, tone=0.5, seed=0):
    """A puff of noise. `tone` from 0 (dark) to 1 (bright) sets the filter."""
    rng = random.Random(seed)
    out = []
    low = 0.0
    alpha = 0.05 + 0.9 * tone
    for i in range(int(RATE * seconds)):
        t = i / RATE
        low += alpha * (rng.uniform(-1, 1) - low)
        out.append(amp * min(1.0, t / attack) * math.exp(-decay * t) * low)
    fade(out, 0.004)
    return out


def fade(samples, seconds):
    count = min(len(samples), int(RATE * seconds))
    for i in range(count):
        samples[-1 - i] *= i / count


def reverb(dry, wet=0.2, room=0.78, tail=0.6):
    """A small room: four damped comb filters into two allpasses."""
    padded = dry + [0.0] * int(RATE * tail)
    combs = [1557, 1617, 1491, 1422]
    total = [0.0] * len(padded)
    for delay in combs:
        buffer = [0.0] * delay
        index = 0
        store = 0.0
        for i, x in enumerate(padded):
            y = buffer[index]
            store = y * 0.8 + store * 0.2
            buffer[index] = x + store * room
            index = (index + 1) % delay
            total[i] += y * 0.25
    for delay in (556, 225):
        buffer = [0.0] * delay
        index = 0
        for i, x in enumerate(total):
            y = buffer[index]
            buffer[index] = x + y * 0.5
            index = (index + 1) % delay
            total[i] = y - x * 0.5
    out = [d + w * wet for d, w in zip(padded, total)]
    # Trim the silent end.
    last = max((i for i, v in enumerate(out) if abs(v) > 1e-4), default=0)
    out = out[:last + 1]
    fade(out, 0.03)
    return out


def sparkle(count, start, spread, seed, amp=0.25):
    """A scatter of tiny high pings, like light catching glitter."""
    rng = random.Random(seed)
    out = []
    for _ in range(count):
        pitch = note(rng.choice(["C7", "E7", "G7", "A7", "C8"]))
        mix(out, voice(pitch, 0.2, ((1, 1.0, 26), (2.01, 0.2, 40)), amp=rng.uniform(0.4, 1.0) * amp),
            start + rng.uniform(0, spread))
    return out


def chord(names, maker, at=0.0, strum=0.0, **kwargs):
    out = []
    for i, name in enumerate(names):
        mix(out, maker(note(name), **kwargs), at + i * strum)
    return out


def normalise(samples, peak):
    top = max(1e-9, max(abs(s) for s in samples))
    return [s / top * peak for s in samples]


def write_wav(path, samples):
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


def write(name, samples, peak):
    samples = normalise(samples, peak)
    folder = os.path.join(ASSETS, f"{name}.dataset")
    os.makedirs(folder, exist_ok=True)
    filename = f"{name.lower()}.wav"
    write_wav(os.path.join(folder, filename), samples)
    contents = {
        "data": [{"filename": filename, "idiom": "universal",
                  "universal-type-identifier": "com.microsoft.waveform-audio"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"wrote {name}: {len(samples) / RATE:.2f} s")
    return samples


# MARK: - The sounds

def everyday():
    # The tap is barely there, on purpose: a tiny, round pop.
    tap = voice(note("C5"), 0.05, ((1, 1.0, 70),), glide_to=note("G5"), glide_time=0.03)
    write("Tap", tap, peak=0.14)

    # Something saved: a round bubble pop.
    pop = voice(note("D5"), 0.09, ((1, 1.0, 40), (2, 0.18, 60)), glide_to=note("A5"), glide_time=0.05)
    mix(pop, noise(0.02, amp=0.25, decay=200, tone=0.6, seed=2))
    mix(pop, voice(note("A5"), 0.08, ((1, 0.5, 45),), glide_to=note("E6"), glide_time=0.04), 0.07)
    write("Pop", reverb(pop, wet=0.08, tail=0.2), peak=0.35)

    # Sending a message: a quick swoosh up.
    send = voice(note("E5"), 0.11, ((1, 1.0, 22), (2, 0.15, 30)), glide_to=note("E6"), glide_time=0.09)
    mix(send, noise(0.1, amp=0.18, attack=0.05, decay=25, tone=0.9, seed=3))
    write("Send", reverb(send, wet=0.08, tail=0.2), peak=0.25)

    # Nutmeg answering: two wooden notes, falling then settling.
    receive = mix(mallet(note("E6"), 0.25, decay=14), mallet(note("B5"), 0.3, decay=12), 0.075)
    write("Receive", reverb(receive, wet=0.12, tail=0.3), peak=0.2)

    start = mix(mallet(note("G5"), 0.2, decay=16), mallet(note("D6"), 0.25, decay=13), 0.07)
    write("RecordStart", reverb(start, wet=0.1, tail=0.25), peak=0.25)
    stop = mix(mallet(note("D6"), 0.2, decay=16), mallet(note("G5"), 0.25, decay=13), 0.07)
    write("RecordStop", reverb(stop, wet=0.1, tail=0.25), peak=0.22)


def timer_alarm():
    """A kitchen timer: four quick dings, a breath, repeat. The loop is 1.6 s
    and its echo wraps around to the start, so it repeats without a seam."""
    length = int(RATE * 1.6)
    ring = []
    for i in range(4):
        ding = bell(note("E6"), 0.5, decay=7)
        mix(ding, bell(note("G#6"), 0.5, amp=0.35, decay=8))
        mix(ring, ding, i * 0.14)
    ring = reverb(ring, wet=0.15, tail=0.4)
    loop = [0.0] * length
    for i, value in enumerate(ring):
        loop[i % length] += value
    loop = normalise(loop, 0.8)
    write("TimerAlarm", loop, peak=0.8)
    # For the notification: the same ring for about 25 seconds.
    os.makedirs(BUNDLED, exist_ok=True)
    long = loop * 15
    fade(long, 0.2)
    write_wav(os.path.join(BUNDLED, "TimerAlarm.wav"), long)
    print(f"wrote Sounds/TimerAlarm.wav: {len(long) / RATE:.2f} s")


def celebrations():
    # Made it: a wooden run up into a ringing bell chord.
    made = []
    for i, name in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        mix(made, mallet(note(name), 0.4, decay=8), i * 0.065)
    mix(made, chord(["C5", "G5", "C6", "E6", "G6"], bell, seconds=1.3, decay=2.6), 0.33, gain=0.55)
    mix(made, mallet(note("C4"), 0.6, amp=0.7, decay=5), 0.33)
    mix(made, sparkle(10, 0.38, 0.6, seed=11), 0)
    write("MadeIt", reverb(made, wet=0.25, tail=0.8), peak=0.85)

    # Congrats (goals, streak milestones): a little fanfare, ta-ta-ta-daaa.
    congrats = []
    for at, name, length in [(0.0, "G5", 0.25), (0.11, "G5", 0.25), (0.22, "C6", 0.3), (0.36, "E6", 1.3)]:
        mix(congrats, bell(note(name), length, decay=4 if length > 1 else 9), at)
        mix(congrats, mallet(note(name), length, amp=0.6, decay=10), at)
    mix(congrats, chord(["C5", "G5", "C6"], bell, seconds=1.2, decay=2.8), 0.36, gain=0.45)
    mix(congrats, mallet(note("C4"), 0.7, amp=0.8, decay=4), 0.36)
    mix(congrats, sparkle(8, 0.45, 0.6, seed=12, amp=0.2), 0)
    write("Congrats", reverb(congrats, wet=0.25, tail=0.8), peak=0.8)

    # The first meal ever: a swell for the haptic build-up (0.55 s), then
    # the biggest fanfare in the app, with glitter.
    first = voice(note("A3"), 0.6, ((1, 1.0, 0.2), (2, 0.3, 0.4)), amp=0.45, attack=0.5,
                  glide_to=note("E5"), glide_time=0.55)
    mix(first, noise(0.6, amp=0.25, attack=0.5, decay=0.5, tone=0.8, seed=13))
    for i, name in enumerate(["C6", "E6", "G6"]):
        mix(first, mallet(note(name), 0.3, amp=0.7, decay=10), 0.55 + i * 0.06)
    mix(first, chord(["C4", "C5", "E5", "G5", "C6", "E6", "G6", "C7"], bell, seconds=2.0, decay=1.8), 0.73,
        gain=0.5)
    mix(first, mallet(note("C3"), 1.0, amp=0.9, decay=3), 0.73)
    mix(first, sparkle(22, 0.75, 1.1, seed=14), 0)
    write("FirstMeal", reverb(first, wet=0.3, tail=1.0), peak=0.9)

    # A new look for Nutmeg: a magic sweep up into a cascade of chimes.
    unlock = voice(note("C4"), 0.35, ((1, 1.0, 1.5), (2, 0.3, 2), (3, 0.1, 3)), amp=0.5, attack=0.03,
                   glide_to=note("C6"), glide_time=0.33)
    mix(unlock, noise(0.35, amp=0.2, attack=0.2, decay=4, tone=0.9, seed=15))
    for i, name in enumerate(["C6", "E6", "G6", "C7", "E7"]):
        mix(unlock, bell(note(name), 0.8, amp=0.8, decay=4), 0.32 + i * 0.055)
    mix(unlock, sparkle(12, 0.4, 0.7, seed=16), 0)
    write("Unlock", reverb(unlock, wet=0.3, tail=0.9), peak=0.8)

    # Welcome to Plus: four strummed chords that lift (I, IV, V, I) and a big
    # ringing finish.
    welcome = []
    for i, names in enumerate([["C4", "E4", "G4", "C5"], ["F4", "A4", "C5", "F5"],
                               ["G4", "B4", "D5", "G5"], ["C5", "E5", "G5", "C6"]]):
        mix(welcome, chord(names, mallet, strum=0.025, seconds=0.5, decay=6), i * 0.26, gain=0.8)
    mix(welcome, chord(["C4", "G4", "C5", "E5", "G5", "C6", "E6", "G6"], bell, seconds=2.0, decay=1.8), 1.04,
        gain=0.5)
    mix(welcome, mallet(note("C3"), 1.0, amp=0.9, decay=3), 1.04)
    mix(welcome, sparkle(22, 1.05, 1.2, seed=17), 0)
    write("PlusWelcome", reverb(welcome, wet=0.3, tail=1.0), peak=0.9)


def main():
    everyday()
    timer_alarm()
    celebrations()


if __name__ == "__main__":
    main()
