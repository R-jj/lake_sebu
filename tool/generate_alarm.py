"""Generates assets/sounds/order_alarm.wav — a looping two-tone order alarm.

Pattern (repeats twice in the file so the loop sounds continuous):
  beep 880 Hz  (0.18s) - pause - beep 660 Hz (0.18s) - long pause
"""
import math
import struct
import wave

SAMPLE_RATE = 44100

def tone(freq, duration, volume=0.55):
    n = int(SAMPLE_RATE * duration)
    fade = int(SAMPLE_RATE * 0.01)  # 10ms fade in/out to avoid clicks
    samples = []
    for i in range(n):
        v = volume * math.sin(2 * math.pi * freq * i / SAMPLE_RATE)
        if i < fade:
            v *= i / fade
        elif i > n - fade:
            v *= (n - i) / fade
        samples.append(v)
    return samples

def silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)

# One alarm "pulse": high beep, short gap, lower beep, gap before repeat
pulse = (
    tone(880, 0.18)
    + silence(0.10)
    + tone(660, 0.18)
    + silence(0.54)
)

frames = pulse + pulse

with wave.open("assets/sounds/order_alarm.wav", "w") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(SAMPLE_RATE)
    f.writeframes(b"".join(
        struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in frames
    ))

print("written assets/sounds/order_alarm.wav", len(frames) / SAMPLE_RATE, "seconds")
