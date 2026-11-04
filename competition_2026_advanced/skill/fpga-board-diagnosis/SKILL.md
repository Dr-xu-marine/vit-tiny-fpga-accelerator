---
name: fpga-board-diagnosis
description: Diagnose FPGA board inference in staged JTAG DDR ABI upload compute and result checks while preserving evidence and session continuity. Use after hardware download or a Golden mismatch; never silently reset or rerun a failed job.
---
# Staged board diagnosis
1. Bind bitstream/LTX/Host ABI/data SHA. Require exactly one intended hardware AXI object; stale handles are BLOCKED.
2. Read identity, calibration and busy/error/status flags. Preserve current results before any reset, reprogramming or upload.
3. Verify bounded data upload and readback before a controlled start. Separate transport PASS from numeric PASS.
4. Capture all 1000 outputs twice read-only; compare each code and read stability. Correct top1 does not close byte mismatches.
5. Record session continuity explicitly. If reset/reprogram/power cycle intervened, later DDR contents cannot establish the original job's cause.
6. Locate first divergence using exact-source local or scoped RTL tests. These exclude real DDR/CDC unless explicitly modeled.
Do not download, write memory, reset, call MIG tests or start inference without scope authorization. This distributed package contains only an offline session checker, not live JTAG commands.
