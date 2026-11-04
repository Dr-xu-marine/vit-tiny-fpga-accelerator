# Reproduction guide

## 1. Review and saved-evidence checks

Read README, STATUS and the original report. Use Python 3.11+ and run `python -B tools/audit_release.py`, then `python -B tools/check_saved_evidence.py` from the repository root. These scripts use the standard library, access saved files and launch no simulator, Vivado, or hardware operation.

## 2. Reference algorithms

`golden/golden.py` contains integer NumPy full12 inference and imports adjacent `integer_ln.py`. `golden/host_input.py` describes preprocessing. These are inherited reference algorithms, not evidence that the current hardware candidate passed. NumPy is needed for Golden; image preparation additionally needs Pillow. Historical prepare/evaluation recipes are `.txt` references in `historical/golden/`.

Before numerical inference obtain authorized matching `contract.json`, `integer_parameters.npz`, inputs and fixtures and check SHA in the exclusion manifest. Do not mix parameter sets or manufacture Golden intermediates inside the DUT. No new full-network run is part of publication preparation.

## 3. Board project preparation (future manual action; not tested here)

Install AMD Vivado **2023.2**, Virtex UltraScale+ xcvu9p device support, and applicable IP/tool entitlements. Target `xcvu9p-flga2104-2L-e`, VCU118 with VCCINT 0.85V. Configuration bank voltage is a different property.

`ip/configuration/` preserves the actual synthesis BD/XCI descriptors. They may contain historical paths; they are provenance/configuration references and must NOT be opened as a ready portable project. Vendor generated output products are excluded. `scripts/bd_166p7.tcl` adapts the actual `bd_after.tcl` recipe only for release-local runtime paths. `scripts/create_project.tcl` prepares a fresh project under `build/` and generates IP/wrapper; it does not run synthesis/place/route/bitstream. It has NOT been executed in this publication task and is not a clean-build certification.

A future authorized user may invoke from a release-root working directory:

```powershell
vivado -mode batch -source scripts/create_project.tcl
```

Do not run this while preserving another test's resources. The script refuses an existing project and requires the matching program ROM. Keep generated clock constraints and vendor IP models unchanged. Top is `w8_platform_wrapper`; retain the DDR-generated clock and constraints. The board XDC and 166.7MHz clock/CDC contract are included; the complete historical implementation-stage recipes are text references in `historical/build_scripts/`. Port those recipes explicitly to new release-local outputs before a future implementation. No standalone `effective_final.xdc` is supplied as a replacement for generated IP constraints.

## 4. Testbench references

`testbench/` retains self-checking tests. Path-only test adapters are documented in `publication/path_adapters.json`; active synthesis RTL is unchanged. Some TBs refer to withheld model-derived fixtures or supporting historical modules. They are provided for review and future rebinding, not advertised as an immediately runnable complete regression suite. The test-only paths have been mapped from old `tests/` to release `testbench/`. Any future runner must use the release-local include paths and run from the release root. See the excluded dependency manifest before attempting full-network checks.

Future candidate validation must follow the documented local/datapath/scheduling/interface/architecture/global/final impact classification, source-bound Golden, applicable failure injection, and clean native exit. L3 requires all257 checkpoints, 11,532,400 values and1000 actual host classification outputs bit-exact. Old16-lane tests do not establish new128 path coverage. A build cache hit never supplies numerical PASS. Abnormal XSim exit is a strict failure.

## 5. Manual hardware flow (future)

`host/first_test.tcl` and `host/host_w8.tcl` are retained without changes. They do not automatically program a device but DO write DDR and start inference when manually sourced. First obtain a separately authorized matching BIT/LTX and place authorized `ddr.bin` and expected output beside the Host script. Do not commit these assets. The bitstream/DCP/LTX are intentionally absent from this repository.

Preserve all outputs and session identity; `first_test.tcl` saves observed results locally. The historical first output failed 921/1000. Do not substitute a later reset session's memory sample for that inference or describe an eventual rerun as this saved result.

## Remaining reproduction limits

Clean-project creation, IP regeneration, compile/synthesis/P&R, full-network simulation and board execution were not run for this package. Vendor configuration and historical recipes are available, but missing entitled data plus untested path/runner integration prevent a claim of one-command or fully independent reproduction.
