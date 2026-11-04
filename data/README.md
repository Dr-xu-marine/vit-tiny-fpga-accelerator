# Runtime dependencies

Included: project-authored `package/program.hex` (13024 instructions), `package/package.json` (DDR layout and hashes), and preprocessing metadata. The instruction ROM schedules memory/operator work; learned tensor bytes are in the separately excluded DDR payload.

Not included: pretrained weights, `integer_parameters.npz`, learned/calibration contract, ImageNet image, input patches, network fixture, `ddr.bin`, `ddr512.hex`, model-derived LN/aux/short-case data. See `publication/excluded_dependencies.json` for exact original path, SHA-256 and size.

For an authorized reproduction, obtain the SAME model/input assets from their rights holder and verify the listed SHA; another parameter file is a different experiment. Place authorized files only in the release-local `data/` and `testbench/` paths as appropriate. Those private binary assets are ignored by Git. The original paths in evidence are provenance references, not locations to overwrite.

The saved `evidence/board/expected_1000.hex` and the two captured outputs in the competition evidence are included to reproduce the documented mismatch without redistributing weights or images.

No weight download URL or entitlement is invented. Complete from-scratch full-network/board reproduction remains dependent on these externally obtained assets.
