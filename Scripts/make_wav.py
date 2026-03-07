#!/usr/bin/env python3
"""Create placeholder silent WAV files for the Xcode project."""
import struct
import os

def make_silent_wav(path, duration_sec=1.0, sample_rate=16000, bits=16, channels=1):
    num_samples = int(sample_rate * duration_sec)
    data_size = num_samples * channels * (bits // 8)
    byte_rate = sample_rate * channels * (bits // 8)
    block_align = channels * (bits // 8)
    with open(path, "wb") as f:
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + data_size))
        f.write(b"WAVE")
        f.write(b"fmt ")
        f.write(struct.pack("<I", 16))
        f.write(struct.pack("<H", 1))
        f.write(struct.pack("<H", channels))
        f.write(struct.pack("<I", sample_rate))
        f.write(struct.pack("<I", byte_rate))
        f.write(struct.pack("<H", block_align))
        f.write(struct.pack("<H", bits))
        f.write(b"data")
        f.write(struct.pack("<I", data_size))
        f.write(b"\x00" * data_size)

audio_dir = os.path.join(os.path.dirname(__file__), "..", "UtamaAI", "Assets", "Audio")
make_silent_wav(os.path.join(audio_dir, "lion_roar.wav"), 3.0)
make_silent_wav(os.path.join(audio_dir, "ambient_shore.wav"), 5.0)
make_silent_wav(os.path.join(audio_dir, "spawn_shimmer.wav"), 1.0)
make_silent_wav(os.path.join(audio_dir, "transition_whoosh.wav"), 1.5)
print("Created placeholder WAV files")
