# M3 diagnostic status

Current focus: pre-main AROS loader failure caused by selected large real C++
translation units.

Already insufficient as standalone explanations: executable size, CODE size,
symbol hunks, relocation count, high relocation offsets, relocation target mix,
and synthetic relocation-group topology.

`-ffunction-sections -fdata-sections` is not accepted by the Bebbo assembler for
this code and therefore produced no runtime result.

Current experiment: compare normal Release objects with supported `-O0` layout
perturbations of `CSteam.cpp` and `CSpotlight.cpp`. If loader behaviour changes,
continue with physical source-level translation-unit splitting under Release
optimisation.
