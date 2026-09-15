# M3 translation-unit/layout diagnostic

The Bebbo GCC/binutils stack cannot assemble the section names emitted by
`-ffunction-sections -fdata-sections` for this C++ code (`.bss._ZStL8__ioinit`).
Therefore that experiment cannot distinguish the AROS loader failure.

The next diagnostic perturbs the real failing translation units without using
unsupported ELF-style per-function sections:

- `CSteam.cpp`
- `CSpotlight.cpp`

For each source, CI keeps the normal Release object as the baseline and also
compiles an `-O0` variant with the established Amiga ABI flags
`-m68020 -msoft-float -noixemul`. Each object is linked into the same minimal
object-probe harness and its Amiga HUNK layout is inspected.

Interpretation:

- If the Release probe fails before `main()` while the O0 probe reaches it,
  code generation/layout is sufficient to trigger or avoid the loader issue.
  We should then narrow this using source-level extraction into smaller
  translation units while preserving Release optimisation.
- If both variants fail, optimisation/layout perturbation alone is insufficient;
  proceed directly to source-level extraction of methods from the two classes.
- If both variants pass, the diagnostic harness is not reproducing the known
  isolated-object failure and must be corrected before drawing conclusions.

The workflow is `.github/workflows/amiga-m3-tu-split.yml`.
