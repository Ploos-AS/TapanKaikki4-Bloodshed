# M3 next loader isolation work

1. Compare Release and `-O0` HUNK output for `CSteam` and `CSpotlight`.
2. If `-O0` changes loader behaviour, identify the code/layout delta.
3. Physically extract roughly half of one failing class's method definitions to
   a second `.cpp` while preserving the public class/interface and Release
   optimisation.
4. Repeat as a binary split until the smallest loader-sensitive source region
   is isolated.
5. Apply the minimal source split as the Amiga-specific build layout workaround
   only if it is reproducible and does not alter game semantics.

Do not change the established ABI flags during this isolation.
