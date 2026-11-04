# Source-to-public layout

Exact file-level mapping and hashes: `source_manifest.json`. Original absolute paths in reports identify provenance; they are not executable release paths.

| Original source | Public location |
|---|---|
| Actual synthesis list in downclock delivery | `evidence/build/ACTUAL_SYNTH_INPUTS_166.json` |
| bank_reset candidate active `rtl/` | `rtl/` (exact active-source bytes) |
| bank_reset board core / board_closure clock metadata | `rtl/board/` |
| bank_reset `tests/` | `testbench/` (`tests/aux` -> `testbench/aux_cases` for Windows Git); withheld files in exclusion manifest |
| jointfix inherited `software/` | `golden/` algorithms; other recipes as historical text |
| bank_reset program ROM/layout | `data/package/` |
| actual host75_synth BD/XCI | `ip/configuration/` |
| 166.7MHz `bd_after.tcl` | exact `historical/bd_after.tcl.txt`; adapted `scripts/bd_166p7.tcl` |
| downclock build Tcl | `historical/build_scripts/*.tcl.txt` |
| real board clock/CDC constraints | `constraints/` |
| board kit Host and first test | `host/` |
| competition report/evidence/Skill | same `competition_2026_advanced/` relative layout; duplicate QA rasters omitted |

The `active_sources` array is the authoritative list. Other baseline modules inside testbench and historical material do not form the candidate's synthesis source set. Vendor files are regenerated from configurations; a copied XCI is not a claim to redistribute its implementation.
