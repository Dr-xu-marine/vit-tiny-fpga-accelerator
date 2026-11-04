---
name: vivado-evidence-audit
description: Audit existing Vivado setup hold pulse width route and resource reports against a frozen candidate. Use for evidence review and stage-specific PASS decisions; does not run implementation or manufacture constraints.
---
# Vivado evidence audit
1. Bind part, source/DCP SHA, tool version and effective/generated clocks before reading results.
2. Parse raw timing summary with `scripts/check.py`; retain raw reports and all negative endpoints.
3. Require setup WNS>=0/TNS=0, hold WHS>=0/THS=0, pulse width margins>=0 and zero unrouted/error nets.
4. Inspect unconstrained paths, clock interaction, DRC and CDC separately. Warning presence is not automatic failure or automatic clearance; classify every warning family.
5. Audit actual DSP register properties and intended BRAM classes from mapped/routed cells, not RTL attributes alone.
6. Report scope precisely: PE, complete GEMM or full board. Bitstream generation never proves inference correctness.
Do not insert false paths/multicycle exceptions, relax a clock without changing its real generator, or reuse PASS across different netlists.
See `references/evidence.md`. This package reviews existing files only.
