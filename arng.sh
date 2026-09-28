#!/bin/bash

INPUT="output1000_128bit.txt"
OUTPUT="n32_output.txt"

# Clear/create output file
> "$OUTPUT"

# Read input 8 lines at a time
while true; do
    chunk=()

    for i in {1..8}; do
        IFS= read -r line <&3 || break
        
        # Reverse the string to read from right to left
        if [[ -n "$line" ]]; then
            reversed_line=$(rev <<< "$line")
            chunk+=("$reversed_line")
        fi
    done

    # Stop if fewer than 8 lines remain
    [[ ${#chunk[@]} -lt 8 ]] && break

    # Combine 8 x 128-bit reversed lines = 1024 bits
    combined=$(printf "%s" "${chunk[@]}")

    # Split into 32 x 32-bit lines
    for ((i=0; i<32; i++)); do
        start=$((i * 32))
        echo "${combined:start:32}" >> "$OUTPUT"
    done

    # Empty line between chunks
   # echo "" >> "$OUTPUT"

done 3< "$INPUT"

echo "Done. Output written to $OUTPUT"
