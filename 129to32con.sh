#!/usr/bin/env bash

input_file="${1:-input.txt}"
output_file="${2:-output.txt}"

if [[ ! -f "$input_file" ]]; then
    echo "Error: File '$input_file' not found." >&2
    exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove any trailing CR or accidental whitespace
    bits="${line//[[:space:]]/}"
    
    # Skip empty lines
    [[ -z "$bits" ]] && continue

    # Extract 32-bit slices: ${variable:offset:length}
    # Offset 96 = Last 32 bits (bits 97-128)
    # Offset 64 = 2nd last 32 bits (bits 65-96)
    # Offset 32 = 3rd last 32 bits (bits 33-64)
    # Offset  0 = First 32 bits (bits 1-32)
    printf "%s\n%s\n%s\n%s\n" \
        "${bits:96:32}" \
        "${bits:64:32}" \
        "${bits:32:32}" \
        "${bits:0:32}"
done < "$input_file" > "$output_file"
