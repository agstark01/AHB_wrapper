#!/usr/bin/env python3
"""
Convert a bulk MNIST-style text file where each image is stored as
32 lines of 32-bit words (1024 bits total: 784 real image bits +
240 padding bits) back into 28x28 bit images (28 lines of 28 bits
per image), written back-to-back with no separators.

Supports configurable bit/word ordering ("endianness") since the
32-bit serialization direction can vary depending on how the
original hardware/software packed the bits.

Modes (--endian):
  reverse-bits-per-word   Reverse the 32 bits within each word line
                          before concatenating. (CONFIRMED CORRECT
                          for the sample data — produces a clean digit.)
  none                    Use each word line as-is (original/naive
                          interpretation — produced noise on the
                          sample data, kept here for comparison).
  reverse-bytes-per-word  Keep bit order within each 8-bit byte, but
                          reverse the order of the 4 bytes in the word.
  reverse-bits-per-byte   Keep byte order, but reverse bits within
                          each 8-bit byte.
  reverse-whole-stream    Reverse the entire 784-bit stream after
                          extraction (not per-word).
  reverse-word-order      Keep each word's bits as-is, but reverse the
                          order of the 32 words within the block.

Usage:
    python convert_mnist_32bit_to_28x28_v2.py input.txt output.txt \\
        [--endian reverse-bits-per-word]
"""

import sys
import argparse

WORD_LEN = 32
LINES_PER_IMAGE = 32
BITS_PER_IMAGE = 1024
IMG_SIDE = 28
IMG_BITS = IMG_SIDE * IMG_SIDE  # 784


def transform_block(block, mode):
    """block: list of 32 strings (each 32 chars of '0'/'1'). Returns a
    single concatenated bitstring per the chosen ordering mode."""
    if mode == "none":
        return "".join(block)

    if mode == "reverse-bits-per-word":
        return "".join(w[::-1] for w in block)

    if mode == "reverse-bytes-per-word":
        def byteswap(w):
            bytes_ = [w[i:i + 8] for i in range(0, WORD_LEN, 8)]
            return "".join(bytes_[::-1])
        return "".join(byteswap(w) for w in block)

    if mode == "reverse-bits-per-byte":
        def bitrev_bytes(w):
            bytes_ = [w[i:i + 8][::-1] for i in range(0, WORD_LEN, 8)]
            return "".join(bytes_)
        return "".join(bitrev_bytes(w) for w in block)

    if mode == "reverse-word-order":
        return "".join(block[::-1])

    if mode == "reverse-whole-stream":
        # concatenate normally, extraction step will reverse after slicing
        return "".join(block)

    raise ValueError(f"Unknown mode: {mode}")


def convert(input_path: str, output_path: str, mode: str) -> int:
    with open(input_path, "r") as f:
        lines = [line.strip() for line in f if line.strip() != ""]

    if len(lines) % LINES_PER_IMAGE != 0:
        print(
            f"Warning: total lines ({len(lines)}) is not a multiple of "
            f"{LINES_PER_IMAGE}. Trailing incomplete image block(s) will be skipped."
        )

    num_images = len(lines) // LINES_PER_IMAGE
    written = 0

    with open(output_path, "w") as out:
        for i in range(num_images):
            block = lines[i * LINES_PER_IMAGE: (i + 1) * LINES_PER_IMAGE]

            if any(len(w) != WORD_LEN or any(c not in "01" for c in w) for w in block):
                print(f"Skipping image {i}: malformed word line(s).")
                continue

            bitstream = transform_block(block, mode)

            if len(bitstream) != BITS_PER_IMAGE:
                print(f"Skipping image {i}: expected {BITS_PER_IMAGE} bits, "
                      f"got {len(bitstream)}.")
                continue

            image_bits = bitstream[:IMG_BITS]
            if mode == "reverse-whole-stream":
                image_bits = image_bits[::-1]

            for row in range(IMG_SIDE):
                start = row * IMG_SIDE
                out.write(image_bits[start:start + IMG_SIDE] + "\n")

            written += 1

    return written


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", help="input bulk txt file (32-bit-word images)")
    parser.add_argument("output", help="output txt file (28x28 bit images, sequential)")
    parser.add_argument(
        "--endian",
        default="reverse-bits-per-word",
        choices=[
            "reverse-bits-per-word",
            "none",
            "reverse-bytes-per-word",
            "reverse-bits-per-byte",
            "reverse-whole-stream",
            "reverse-word-order",
        ],
        help="bit/word ordering mode (default: reverse-bits-per-word, "
             "confirmed correct on sample data)",
    )
    args = parser.parse_args()

    n = convert(args.input, args.output, args.endian)
    print(f"Done. Converted {n} image(s) using mode '{args.endian}' -> {args.output}")
