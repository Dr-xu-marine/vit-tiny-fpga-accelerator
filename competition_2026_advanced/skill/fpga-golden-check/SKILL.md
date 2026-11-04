---
name: fpga-golden-check
description: Compare frozen byte-code outputs and locate the first mismatch with strict native-exit and dump gates. Use for FPGA Golden logs and captured host outputs, not for claiming full-network coverage from a local test.
---
# FPGA Golden checking
Read `references/evidence.md` before use. Work on copied evidence and bind exact source/data SHA.
1. Establish scope: local L1, affected-path L2, or complete-network L3. Missing scope is BLOCKED.
2. Check native launcher and kernel exits independently. Both exit0 plus any new crash dump is FAIL.
3. Run `scripts/check.py expected.hex actual.hex`; codes must be two hexadecimal digits, one per line.
4. Report count, mismatches, first index, unsigned and signed codes. Different lengths are FAIL.
5. Run a copied one-bit corruption test; expected detection is a checker PASS, not numerical PASS.
6. Require actual expected checkpoint/value/Host counts for L3. A cache hit or old source PASS grants no new numerical PASS.
Never write expected values into DUT storage or overwrite original traces. A matching label or top1 alone is insufficient.
