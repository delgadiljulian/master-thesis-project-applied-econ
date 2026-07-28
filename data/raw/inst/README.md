# Insumos raw de INST

`world_bank_wgi/inst_wgi_inputs_1996_2024.csv` y su archivo equivalente para
Stata contienen por separado los tres estimadores de Worldwide Governance
Indicators adoptados por la tesis:

- control de la corrupción (`GOV_WGI_CC.EST`);
- Estado de derecho (`GOV_WGI_RL.EST`);
- efectividad gubernamental (`GOV_WGI_GE.EST`).

La capa raw conserva los valores publicados en su escala original aproximada
de -2,5 a 2,5. No calcula todavía el índice agregado `INST`, no estandariza, no
interpola y no imputa observaciones faltantes. Las versiones de WGI expresadas
como puntajes, rangos, errores estándar, intervalos de confianza o número de
fuentes tampoco forman parte de este extracto.

En `data/processed`, `INST` se construye como el promedio simple de los tres
estimadores y solamente cuando los tres están observados. No se utiliza ningún
índice institucional alternativo.

La descarga original contiene datos entre 1996 y 2024. WGI no publicó
observaciones para 1997, 1999 ni 2001; estas ausencias son estructurales y se
conservan como tales. El extracto conserva cobertura hasta 2022 para mantener
trazabilidad con las demás fuentes raw, aunque el período econométrico efectivo
de la tesis es 1996-2021.

`world_bank_wgi/inst_raw_coverage_dres20_1996_2022.csv` documenta la cobertura
individual y conjunta para los 55 países de la muestra DRES. En los años
publicados, Estado de derecho tiene cobertura completa. Control de la
corrupción y efectividad gubernamental carecen de ocho observaciones de Nauru
entre 1996 y 2006. Por ello, los tres componentes están disponibles
conjuntamente en 1.312 de las 1.320 celdas publicadas (99,4 %) y en 1.312 de las
1.485 celdas del período completo (88,4 %), contando los tres años
estructuralmente ausentes.

El script reproducible es
[`scripts/data/raw/inst/inst_wgi_raw.R`](../../../scripts/data/raw/inst/inst_wgi_raw.R).

La construcción definitiva se realiza mediante
[`scripts/data/processed/inst/inst_processed.R`](../../../scripts/data/processed/inst/inst_processed.R).
