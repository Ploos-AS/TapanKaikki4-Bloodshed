#!/usr/bin/env python3
"""Generate m68k assembly with a controlled CODE size and RELOC32 density."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--code-kib", type=int, required=True)
    parser.add_argument("--relocs", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    target = args.code_kib * 1024
    reloc_bytes = args.relocs * 4
    if args.relocs < 1 or reloc_bytes + 2 > target:
        raise SystemExit("relocation count does not fit requested code size")

    # Spread relocation-bearing longwords over the requested text span. The
    # final RTS keeps the symbol callable while the generated function itself
    # is never executed by the runtime probe.
    free = target - reloc_bytes - 2
    base_gap, extra = divmod(free, args.relocs)

    lines = [
        ".text",
        f".globl _m3_density_{args.code_kib}_{args.relocs}",
        f"_m3_density_{args.code_kib}_{args.relocs}:",
    ]
    for index in range(args.relocs):
        gap = base_gap + (1 if index < extra else 0)
        if gap:
            lines.append(f"    .space {gap},0")
        lines.append("    .long _m3_density_target")
    lines.extend(
        [
            "    rts",
            ".data",
            ".globl _m3_density_target",
            "_m3_density_target:",
            "    .long 0",
            ".bss",
            "    .space 6612",
            "",
        ]
    )
    args.output.write_text("\n".join(lines), encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
