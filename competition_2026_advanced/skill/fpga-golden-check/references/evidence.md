# Evidence and boundaries
Original workflow: experiments/board_closure_20261030/full72_recovery_20261030 (257 checkpoints, 11,532,400 values, 1000 Host outputs, clean native exit) and experiments/board_logit_diagnostic_20261103/capture_1793697684_24312_3377448321 (921 mismatches, stable repeated reads).
This newly packaged helper is tested offline on copies of those byte outputs. It does not rerun the old RTL, certify a new simulator, or certify the current bank-modified full network.
Native exit gate tests include exit0 with a dump => FAIL. Original XSim incident evidence is why this rule is mandatory; the helper cannot recover missing native process records.
