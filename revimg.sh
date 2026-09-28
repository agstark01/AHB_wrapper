#!/bin/bash

INPUT="imggg.txt"
OUTPUT="output.txt"

> "$OUTPUT"

while true; do
    chunk=()

    for i in {1..8}; do
        IFS= read -r line <&3 || break
        [[ -n "$line" ]] && chunk+=("$line")
    done

    [[ ${#chunk[@]} -lt 8 ]] && break

    # Combine 8 x 128-bit lines = 1024 bits
    combined=$(printf "%s" "${chunk[@]}")

    # Split into 32-bit lines and reverse each line
    for ((i=0; i<38; i++)); do
        start=$((i * 28))
        word="${combined:start:28}"

        # Reverse the 32 bits
        reversed=$(echo "$word" | rev)

        echo "$reversed" >> "$OUTPUT"
    done

    echo "" >> "$OUTPUT"

done 3< "$INPUT"

echo "Done. Output written to $OUTPUT"
