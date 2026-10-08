# M3 function/data section experiment

Result: **toolchain unsupported**; no runtime verdict.

With the normal Amiga flags restored, the baseline Release build succeeds.
The Bebbo GCC 6.5/binutils stack fails when compiling the section-split variant:

```
Error: unknown pseudo-op: `.bss._zstl8__ioinit'
```

Observed while compiling `CDrawArea.cpp` and `CEditableLevel.cpp` with
`-ffunction-sections -fdata-sections`.

Consequently this experiment does not show whether per-function sections would
fix the AROS pre-main loader failure. M3 continues with supported source/code
layout perturbation and, if indicated, physical translation-unit splitting.
