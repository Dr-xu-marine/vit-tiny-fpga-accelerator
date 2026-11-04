# IP configurations, not vendor implementation

`configuration/` is the exact `.bd` and `.xci` set from the actual166.7MHz synthesis project. Some descriptors refer to historical source paths and generated directories. Treat them as configuration evidence. Use the adapted BD recipe and a fresh project rather than reopening these paths in place.

Generate vendor IP with Vivado2023.2 and matching device/IP entitlement. Do not replace DDR4/clock/primitive behavior with simplified substitutes. `board_repo/` includes the original AMD Apache-2.0 metadata subset and notice; the board JPEG image was omitted. The generated IP/netlist/cache/model implementations are not redistributed.
