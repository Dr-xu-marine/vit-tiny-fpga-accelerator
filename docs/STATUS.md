# Evidence status — 2026-11-04

- Scope: actual 166.7MHz downclock board candidate based on full128_bank_reset_fix_20261102, not the old top-level simplified 8×8 design.
- TIMING_PASS: saved routed report WNS +0.073ns, WHS +0.005ns, WPWS +0.039ns; no failing setup/hold/pulse endpoints; TNS/THS/TPWS zero. No new implementation was run for this package.
- BOARD_NUMERIC_FAIL: first saved 1000-class output has 921 differing values. Repeated-read mismatch count is zero. Cause UNKNOWN.
- A user-confirmed reprogram/power/reset separates subsequent DDR samples from the first inference; those samples cannot establish the first failure's cause.
- Current candidate P has no final full12 L3 signoff; historical C results cannot be inherited across its changed active RTL.
- No validated correct board FPS, sustained latency, power/energy-efficiency or final board numerical PASS is claimed.
- Historical 512-image engineering calibration is scoped to that sample: FP32 383/512, integer 377/512, drop 1.171875 percentage points. It is not a 50000-image result, hardware accuracy measurement, or result newly run here.

Packaging operations performed: file selection/copy, hashing, offline saved-evidence parsing, privacy/size/path checks. R2/new inference/RTL changes/Vivado/XSim/board operations: zero.
