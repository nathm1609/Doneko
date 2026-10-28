#!/usr/bin/env python3
"""« Pop » feutré de l'iPhone (DonekoiOS/Resources/Pop.wav) : le Mac joue le son système Pop, absent d'iOS.
Une sinusoïde de 90 ms qui glisse de 900 à 320 Hz, attaque de 4 ms et extinction rapide.
Usage : python3 Artwork/make-pop.py"""
import math
import os
import struct
import wave

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RATE = 44100
DURATION = 0.09
out = wave.open("DonekoiOS/Resources/Pop.wav", "wb")
out.setnchannels(1)
out.setsampwidth(2)
out.setframerate(RATE)
phase = 0.0
frames = bytearray()
for i in range(int(RATE * DURATION)):
    t = i / RATE
    frequency = 320 + (900 - 320) * math.exp(-t / 0.02)
    phase += 2 * math.pi * frequency / RATE
    envelope = min(t / 0.004, 1) * math.exp(-t / 0.022)
    frames += struct.pack("<h", int(0.8 * 32767 * envelope * math.sin(phase)))
out.writeframes(bytes(frames))
out.close()
