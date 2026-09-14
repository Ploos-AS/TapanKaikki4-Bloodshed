#!/usr/bin/env python3
"""Inspect classic Amiga HUNK executables without external dependencies.

The M3 loader diagnostics use this to compare raw HUNK layout and relocation
locations between binaries that do and do not reach main() under AROS/FS-UAE.
"""

from __future__ import annotations

import argparse
import struct
import sys
from collections import Counter
from pathlib import Path

HUNK_UNIT = 999
HUNK_NAME = 1000
HUNK_CODE = 1001
HUNK_DATA = 1002
HUNK_BSS = 1003
HUNK_RELOC32 = 1004
HUNK_RELOC16 = 1005
HUNK_RELOC8 = 1006
HUNK_EXT = 1007
HUNK_SYMBOL = 1008
HUNK_DEBUG = 1009
HUNK_END = 1010
HUNK_HEADER = 1011
HUNK_OVERLAY = 1013
HUNK_BREAK = 1014
HUNK_DREL32 = 1015
HUNK_DREL16 = 1016
HUNK_DREL8 = 1017
HUNK_LIB = 1018
HUNK_INDEX = 1019
HUNK_RELOC32SHORT = 1020
HUNK_RELRELOC32 = 1021
HUNK_ABSRELOC16 = 1022

NAMES = {
    HUNK_UNIT: "UNIT", HUNK_NAME: "NAME", HUNK_CODE: "CODE",
    HUNK_DATA: "DATA", HUNK_BSS: "BSS", HUNK_RELOC32: "RELOC32",
    HUNK_RELOC16: "RELOC16", HUNK_RELOC8: "RELOC8", HUNK_EXT: "EXT",
    HUNK_SYMBOL: "SYMBOL", HUNK_DEBUG: "DEBUG", HUNK_END: "END",
    HUNK_HEADER: "HEADER", HUNK_OVERLAY: "OVERLAY", HUNK_BREAK: "BREAK",
    HUNK_DREL32: "DREL32", HUNK_DREL16: "DREL16", HUNK_DREL8: "DREL8",
    HUNK_LIB: "LIB", HUNK_INDEX: "INDEX", HUNK_RELOC32SHORT: "RELOC32SHORT",
    HUNK_RELRELOC32: "RELRELOC32", HUNK_ABSRELOC16: "ABSRELOC16",
}

MEM_MASK = 0xC0000000
TYPE_MASK = 0x3FFFFFFF


class Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def u32(self) -> int:
        if self.pos + 4 > len(self.data):
            raise ValueError(f"unexpected EOF at 0x{self.pos:x}")
        v = struct.unpack_from(">I", self.data, self.pos)[0]
        self.pos += 4
        return v

    def u16(self) -> int:
        if self.pos + 2 > len(self.data):
            raise ValueError(f"unexpected EOF at 0x{self.pos:x}")
        v = struct.unpack_from(">H", self.data, self.pos)[0]
        self.pos += 2
        return v

    def skip_longs(self, n: int) -> None:
        self.pos += n * 4
        if self.pos > len(self.data):
            raise ValueError("block extends past EOF")

    def skip_bytes(self, n: int) -> None:
        self.pos += n
        if self.pos > len(self.data):
            raise ValueError("block extends past EOF")


def parse_name(r: Reader) -> str:
    n = r.u32()
    raw = r.data[r.pos:r.pos + n * 4]
    r.skip_longs(n)
    return raw.rstrip(b"\0").decode("latin-1", "replace")


def parse_reloc_long(r: Reader, source_hunk: int, kind: str, relocs: list[tuple]) -> int:
    total = 0
    while True:
        count = r.u32()
        if count == 0:
            break
        target = r.u32()
        for _ in range(count):
            off = r.u32()
            relocs.append((kind, source_hunk, target, off))
        total += count
    return total


def parse_reloc_short(r: Reader, source_hunk: int, relocs: list[tuple]) -> int:
    total = 0
    start = r.pos
    while True:
        count = r.u16()
        if count == 0:
            break
        target = r.u16()
        for _ in range(count):
            off = r.u16()
            relocs.append(("RELOC32SHORT", source_hunk, target, off))
        total += count
    if (r.pos - start) & 2:
        r.u16()  # word padding to long boundary
    return total


def parse(path: Path) -> dict:
    data = path.read_bytes()
    r = Reader(data)
    first = r.u32() & TYPE_MASK
    if first != HUNK_HEADER:
        raise ValueError(f"expected HUNK_HEADER, got {first}")

    resident_names = []
    while True:
        n = r.u32()
        if n == 0:
            break
        raw = r.data[r.pos:r.pos + n * 4]
        r.skip_longs(n)
        resident_names.append(raw.rstrip(b"\0").decode("latin-1", "replace"))

    table_size = r.u32()
    first_hunk = r.u32()
    last_hunk = r.u32()
    hunk_sizes = []
    for _ in range(table_size):
        raw = r.u32()
        hunk_sizes.append((raw & TYPE_MASK) * 4)

    sequence = ["HEADER"]
    counts = Counter({"HEADER": 1})
    code_sizes = []
    data_sizes = []
    bss_sizes = []
    relocs: list[tuple] = []
    symbols = 0
    debug_bytes = 0
    current_hunk = first_hunk - 1

    while r.pos < len(data):
        raw_type = r.u32()
        htype = raw_type & TYPE_MASK
        name = NAMES.get(htype, f"UNKNOWN_{htype}")
        sequence.append(name)
        counts[name] += 1

        if htype in (HUNK_CODE, HUNK_DATA, HUNK_BSS):
            current_hunk += 1
            nlongs = r.u32() & TYPE_MASK
            nbytes = nlongs * 4
            if htype == HUNK_CODE:
                code_sizes.append(nbytes)
                r.skip_longs(nlongs)
            elif htype == HUNK_DATA:
                data_sizes.append(nbytes)
                r.skip_longs(nlongs)
            else:
                bss_sizes.append(nbytes)
        elif htype in (HUNK_RELOC32, HUNK_RELOC16, HUNK_RELOC8,
                       HUNK_DREL32, HUNK_DREL16, HUNK_DREL8,
                       HUNK_RELRELOC32, HUNK_ABSRELOC16):
            parse_reloc_long(r, current_hunk, name, relocs)
        elif htype == HUNK_RELOC32SHORT:
            parse_reloc_short(r, current_hunk, relocs)
        elif htype == HUNK_SYMBOL:
            while True:
                n = r.u32()
                if n == 0:
                    break
                r.skip_longs(n)
                r.u32()  # symbol value
                symbols += 1
        elif htype == HUNK_DEBUG:
            n = r.u32()
            debug_bytes += n * 4
            r.skip_longs(n)
        elif htype in (HUNK_NAME, HUNK_UNIT):
            parse_name(r)
        elif htype == HUNK_END or htype == HUNK_BREAK:
            pass
        elif htype in (HUNK_OVERLAY, HUNK_LIB, HUNK_INDEX):
            n = r.u32()
            r.skip_longs(n)
        elif htype == HUNK_EXT:
            # Executables produced in this project should not contain EXT.
            # Stop loudly rather than risk silently mis-parsing its tagged format.
            raise ValueError(f"HUNK_EXT encountered at 0x{r.pos - 4:x}")
        else:
            raise ValueError(f"unsupported hunk type {htype} at 0x{r.pos - 4:x}")

    offsets = [x[3] for x in relocs]
    reloc_by_source = Counter(x[1] for x in relocs)
    reloc_by_target = Counter(x[2] for x in relocs)
    reloc_by_kind = Counter(x[0] for x in relocs)
    buckets = Counter()
    for off in offsets:
        buckets[(off // 65536) * 65536] += 1

    return {
        "file_bytes": len(data), "table_size": table_size,
        "first_hunk": first_hunk, "last_hunk": last_hunk,
        "header_sizes": hunk_sizes, "resident_names": resident_names,
        "sequence": sequence, "counts": counts, "code_sizes": code_sizes,
        "data_sizes": data_sizes, "bss_sizes": bss_sizes,
        "relocs": relocs, "symbols": symbols, "debug_bytes": debug_bytes,
        "reloc_by_source": reloc_by_source, "reloc_by_target": reloc_by_target,
        "reloc_by_kind": reloc_by_kind, "buckets": buckets,
    }


def fmt_counter(c: Counter) -> str:
    return ",".join(f"{k}:{v}" for k, v in sorted(c.items(), key=lambda x: str(x[0]))) or "none"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()
    for fn in args.files:
        p = Path(fn)
        try:
            x = parse(p)
        except Exception as exc:
            print(f"FILE={p} ERROR={exc}")
            return 2
        offsets = [r[3] for r in x["relocs"]]
        print(f"=== {p.name} ===")
        print(f"FILE_BYTES={x['file_bytes']}")
        print(f"HUNK_RANGE={x['first_hunk']}..{x['last_hunk']} TABLE_SIZE={x['table_size']}")
        print("HEADER_ALLOC_BYTES=" + ",".join(map(str, x["header_sizes"])))
        print("SEQUENCE=" + " ".join(x["sequence"]))
        print("COUNTS=" + fmt_counter(x["counts"]))
        print("CODE_BYTES=" + ",".join(map(str, x["code_sizes"])))
        print("DATA_BYTES=" + ",".join(map(str, x["data_sizes"])))
        print("BSS_BYTES=" + ",".join(map(str, x["bss_sizes"])))
        print(f"SYMBOLS={x['symbols']} DEBUG_BYTES={x['debug_bytes']}")
        print(f"RELOCS={len(offsets)} RELOC_MIN={min(offsets) if offsets else -1} RELOC_MAX={max(offsets) if offsets else -1}")
        print("RELOC_KINDS=" + fmt_counter(x["reloc_by_kind"]))
        print("RELOC_BY_SOURCE=" + fmt_counter(x["reloc_by_source"]))
        print("RELOC_BY_TARGET=" + fmt_counter(x["reloc_by_target"]))
        print("RELOC_64K_BUCKETS=" + fmt_counter(x["buckets"]))
        high = sum(1 for off in offsets if off >= 0x80000)
        high640 = sum(1 for off in offsets if off >= 0xA0000)
        high704 = sum(1 for off in offsets if off >= 0xB0000)
        print(f"RELOC_GE_512K={high} RELOC_GE_640K={high640} RELOC_GE_704K={high704}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
