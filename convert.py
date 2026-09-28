with open("weight.bin", "r") as f:
    lines = [line.strip() for line in f if line.strip()]

with open("weight_real.bin", "wb") as f:
    for line in lines:
        assert len(line) == 256, f"Invalid line length: {len(line)}"
        assert all(c in "01" for c in line), "Non-binary character found"

        value = int(line, 2)
        f.write(value.to_bytes(32, byteorder="big"))
