#!/usr/bin/env python3
"""
Bulk-convert a text file of 28x28 bit images into 32-bit-word format.

Input:  a txt file containing only 28x28 images back-to-back, no
        separators. Each image = 28 lines, each line = 28 chars of
        '0'/'1'.

Algorithm (exactly as specified):
  1. For each of the 28 rows in an image, reverse that row's 28 bits.
  2. Concatenate all 28 reversed rows into one continuous bitstream
     (784 bits total).
  3. Split that stream into 32-bit chunks -> output word lines.
     784 / 32 = 24.5, so the 25th word is only half-filled by real
     data.
  4. Pad with 0s (completing the 25th word, then adding fully-zero
     words) until the image block reaches 32 lines (1024 bits) total.
  5. Move on to the next image immediately (no blank line/separator).

Usage:
    python pack_28x28_rowreverse_to_32bit.py input.txt output.txt
"""

import sys

IMG_SIDE = 28
IMG_BITS = IMG_SIDE * IMG_SIDE      # 784
WORD_LEN = 32
LINES_OUT = 32
BITS_OUT = WORD_LEN * LINES_OUT     # 1024
PAD_BITS = BITS_OUT - IMG_BITS      # 240


def pack_image(rows):
    """rows: list of 28 strings, each 28 chars of '0'/'1'.
    Returns list of 32 output word-strings (32 chars each)."""
    reversed_rows = [r[::-1] for r in rows]
    bitstream = "".join(reversed_rows)          # 784 bits
    padded = bitstream + "0" * PAD_BITS         # 1024 bits
    return [padded[i:i + WORD_LEN] for i in range(0, BITS_OUT, WORD_LEN)]


def convert(input_path: str, output_path: str) -> int:
    with open(input_path, "r") as f:
        lines = [line.strip() for line in f if line.strip() != ""]

    if len(lines) % IMG_SIDE != 0:
        print(
            f"Warning: total lines ({len(lines)}) is not a multiple of "
            f"{IMG_SIDE}. Trailing incomplete image(s) will be skipped."
        )

    num_images = len(lines) // IMG_SIDE
    written = 0

    with open(output_path, "w") as out:
        for i in range(num_images):
            rows = lines[i * IMG_SIDE:(i + 1) * IMG_SIDE]

            if any(len(r) != IMG_SIDE or any(c not in "01" for c in r) for r in rows):
                print(f"Skipping image {i}: malformed row(s).")
                continue

            words = pack_image(rows)
            for w in words:
                out.write(w + "\n")

            written += 1

    return written


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python pack_28x28_rowreverse_to_32bit.py <input.txt> <output.txt>")
        sys.exit(1)

    inp, outp = sys.argv[1], sys.argv[2]
    n = convert(inp, outp)
    print(f"Done. Packed {n} image(s) -> {outp}")
