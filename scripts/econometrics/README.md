# Econometrics

This folder is reserved for the thesis econometric workflow after the raw data
and the final country-year panel have been completed.

The internal structure will be created as the estimations are implemented. The
expected sequence is:

1. descriptive analysis and panel diagnostics;
2. main ECI model with country and year fixed effects;
3. complementary DIVX model with the same regressors except HHI;
4. export of estimation tables and figures.

The project does not define variable-level alternative proxies or additional
econometric models. The only interaction is `RENTS x INST`, included in both
specified equations.

Econometric scripts should read the final panel from
`data/processed/00_master_panel/` and write generated results under `outputs/`.
