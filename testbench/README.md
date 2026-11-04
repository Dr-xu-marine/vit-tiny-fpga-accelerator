# Self-checking testbench archive

All original candidate testbench source files and small text metadata are included. Synthetic math/requant vectors and bank patterns are included; model-derived HEX/BIN fixtures are withheld unless they are only the saved final output. See `publication/excluded_dependencies.json`.

The release changes test-only absolute file literals and supplies a local `w8_test_paths.vh`; originals are archived. `W8_ROOT`-relative test fixture paths are mapped to `testbench/`; run from the repository root. A future simulation runner must use fresh release-local build outputs, include paths and the exact current RTL. No runnable regression driver is advertised, and no TB was run in this publication task. Historical baseline modules inside testbench are for comparison, not active synthesized RTL.
