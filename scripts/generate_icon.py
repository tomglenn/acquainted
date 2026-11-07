#!/usr/bin/env python3
"""Generate the addon’s small, antialiased person silhouette without dependencies."""
from pathlib import Path
import struct


def generate() -> bytes:
    size, samples = 64, 4

    def inside(x: float, y: float, border: float = 0) -> bool:
        head = (x - 32) ** 2 + (y - 18) ** 2 <= (10 + border) ** 2
        shoulders = ((x - 32) / (21 + border)) ** 2 + ((y - 55) / (22 + border)) ** 2 <= 1
        return head or (shoulders and 33 - border <= y <= 58 + border)

    pixels = bytearray()
    # Uncompressed 32-bit TGA, BGRA pixels, bottom-left origin, eight alpha bits.
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 8)
    for y in reversed(range(size)):
        for x in range(size):
            coverage, colour = 0, 0
            for sy in range(samples):
                for sx in range(samples):
                    px, py = x + (sx + .5) / samples, y + (sy + .5) / samples
                    if inside(px, py, 1.5):
                        coverage += 1
                        colour += 153 if inside(px, py) else 35
            shade = round(colour / coverage) if coverage else 0
            pixels.extend((shade, shade, shade, round(255 * coverage / samples ** 2)))
    return header + pixels


if __name__ == '__main__':
    target = Path(__file__).resolve().parent.parent / 'Acquainted' / 'Media' / 'Unmet.tga'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(generate())
    print(f'Generated {target.name}')
