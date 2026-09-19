#!/usr/bin/env python3
"""Generate a fixed-size Amiga HUNK probe with controlled RELOC32 groups."""

from __future__ import annotations

import argparse
from pathlib import Path


def interleave_targets(counts: tuple[int, int, int]) -> list[str]:
    pools = [
        ["_m3_target_code"] * counts[0],
        ["_m3_target_data"] * counts[1],
        ["_m3_target_bss"] * counts[2],
    ]
    mixed: list[str] = []
    while any(pools):
        for pool in pools:
            if pool:
                mixed.append(pool.pop())
    return mixed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--code-kib", type=int, required=True)
    parser.add_argument("--code-relocs", type=int, required=True)
    parser.add_argument("--data-relocs", type=int, required=True)
    parser.add_argument("--bss-relocs", type=int, required=True)
    parser.add_argument("--data-source-code-relocs", type=int, default=0)
    parser.add_argument("--data-source-data-relocs", type=int, default=0)
    parser.add_argument("--data-source-bss-relocs", type=int, default=0)
    parser.add_argument("--data-bytes", type=int, default=4)
    parser.add_argument("--bss-bytes", type=int, default=6612)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    code_counts = (args.code_relocs, args.data_relocs, args.bss_relocs)
    data_counts = (
        args.data_source_code_relocs,
        args.data_source_data_relocs,
        args.data_source_bss_relocs,
    )
    if any(value < 0 for value in (*code_counts, *data_counts)):
        raise SystemExit("relocation counts must be non-negative")
    if args.data_bytes < 4 or args.bss_bytes < 1:
        raise SystemExit("data/bss sizes must be positive")

    code_targets = interleave_targets(code_counts)
    data_targets = interleave_targets(data_counts)
    if not code_targets:
        raise SystemExit("at least one CODE-source relocation is required")

    target_bytes = args.code_kib * 1024
    reloc_bytes = len(code_targets) * 4
    if reloc_bytes + 2 > target_bytes:
        raise SystemExit("CODE relocations do not fit requested code size")

    data_reloc_bytes = len(data_targets) * 4
    if data_reloc_bytes > args.data_bytes:
        raise SystemExit("DATA-source relocations do not fit requested data size")

    free = target_bytes - reloc_bytes - 2
    base_gap, extra = divmod(free, len(code_targets))
    lines = [
        ".text",
        ".globl _m3_target_code",
        "_m3_target_code:",
        f".globl _m3_targetmix_{args.symbol}",
        f"_m3_targetmix_{args.symbol}:",
    ]
    for index, target in enumerate(code_targets):
        gap = base_gap + (1 if index < extra else 0)
        if gap:
            lines.append(f"    .space {gap},0")
        lines.append(f"    .long {target}")
    lines.append("    rts")

    lines.extend([
        ".data",
        ".globl _m3_target_data",
        "_m3_target_data:",
    ])
    for target in data_targets:
        lines.append(f"    .long {target}")
    data_padding = args.data_bytes - data_reloc_bytes
    if data_padding:
        lines.append(f"    .space {data_padding},0")

    lines.extend([
        ".bss",
        ".globl _m3_target_bss",
        "_m3_target_bss:",
        f"    .space {args.bss_bytes}",
        "",
    ])
    args.output.write_text("\n".join(lines), encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
