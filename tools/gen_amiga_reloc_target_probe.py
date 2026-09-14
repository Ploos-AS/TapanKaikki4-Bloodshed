#!/usr/bin/env python3
"""Generate a fixed-size Amiga CODE hunk with controlled RELOC32 targets."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--code-kib", type=int, required=True)
    parser.add_argument("--code-relocs", type=int, required=True)
    parser.add_argument("--data-relocs", type=int, required=True)
    parser.add_argument("--bss-relocs", type=int, required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    counts = (args.code_relocs, args.data_relocs, args.bss_relocs)
    if any(value < 0 for value in counts):
        raise SystemExit("relocation counts must be non-negative")
    total = sum(counts)
    if total < 1:
        raise SystemExit("at least one relocation is required")

    target_bytes = args.code_kib * 1024
    reloc_bytes = total * 4
    if reloc_bytes + 2 > target_bytes:
        raise SystemExit("relocations do not fit requested code size")

    mixed: list[str] = []
    pools = [
        ["_m3_target_code"] * args.code_relocs,
        ["_m3_target_data"] * args.data_relocs,
        ["_m3_target_bss"] * args.bss_relocs,
    ]
    while any(pools):
        for pool in pools:
            if pool:
                mixed.append(pool.pop())

    free = target_bytes - reloc_bytes - 2
    base_gap, extra = divmod(free, total)
    lines = [
        ".text",
        ".globl _m3_target_code",
        "_m3_target_code:",
        f".globl _m3_targetmix_{args.symbol}",
        f"_m3_targetmix_{args.symbol}:",
    ]
    for index, target in enumerate(mixed):
        gap = base_gap + (1 if index < extra else 0)
        if gap:
            lines.append(f"    .space {gap},0")
        lines.append(f"    .long {target}")
    lines.extend(
        [
            "    rts",
            ".data",
            ".globl _m3_target_data",
            "_m3_target_data:",
            "    .long 0",
            ".bss",
            ".globl _m3_target_bss",
            "_m3_target_bss:",
            "    .space 6612",
            "",
        ]
    )
    args.output.write_text("\n".join(lines), encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
