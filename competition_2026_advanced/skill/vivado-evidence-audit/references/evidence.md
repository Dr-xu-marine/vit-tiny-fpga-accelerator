# Evidence and boundaries
Raw project evidence: experiments/full128_route_20261102/RESULTS.md (200MHz routed WNS -0.583ns FAIL) and experiments/full128_downclock_bit_20261102/delivery_166p7/reports (166.7MHz WNS +0.073ns, WHS +0.005ns).
The raw-summary parser is validated against the latter and injected negative setup/hold/pulse cases. Structural and DRC/CDC decisions still require the associated cells, clocks, route_status, effective XDC and WARNING_REVIEW.md.
No synthesis or route is launched by this skill. Packaging is new; cross-project validation is NOT_RUN.
