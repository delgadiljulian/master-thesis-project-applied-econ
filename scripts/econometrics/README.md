# Econometrics

This folder is reserved for the thesis econometric workflow after the raw data
and the final country-year panel have been completed.

The internal structure will be created as the estimations are implemented. The
expected sequence is:

1. descriptive analysis and panel diagnostics;
2. baseline country and year fixed-effects models;
3. interactions and heterogeneity analysis;
4. robustness and sensitivity checks;
5. export of estimation tables and figures.

Econometric scripts should read the final panel from
`data/processed/00_master_panel/` and write generated results under `outputs/`.
