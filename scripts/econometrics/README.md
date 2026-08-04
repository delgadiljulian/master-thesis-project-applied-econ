# Econometría

Esta carpeta contiene la primera etapa del análisis econométrico del TFM:
los modelos agregados de rentas extractivas del subsuelo (`RENTS`) para
complejidad económica (`ECI`) y diversificación exportadora (`DIVX`).

El análisis fue desarrollado y contrastado mediante dos implementaciones
independientes en Stata:

```text
scripts/econometrics/
  stata-peer-1/
    gmm/
    iv/
    twfe/
  stata-peer-2/
    ECONOMETRIC_STRATEGY.md
    01_twfe_main/
      01_data_preparation_diagnostics.do
      02_twfe_extractive_export_structure.do
      03_twfe_capabilities_stability.do
      04_twfe_full.do
      05_twfe_model_comparison.do
      06_twfe_oil_gas_models.do
      07_twfe_mining_models.do
      08_resource_disaggregated_integrated.do
      run_stata_peer_2.cmd
      run_stata_peer_2.ps1
      WORK_PLAN.md
    02_temporal_fe/
      01_temporal_data_and_samples.do
      02_lagged_and_cumulative_models.do
      03_leads_changes_and_sensitivity.do
      WORK_PLAN.md
    03_within_between/
      WORK_PLAN.md
```

## Alcance

Las dos implementaciones estiman:

1. el modelo principal ECI con efectos fijos por país y año;
2. el modelo complementario DIVX, excluyendo HHI porque
   `DIVX = 1 - HHI`;
3. la interacción `RENTS × INST`;
4. diagnósticos, efectos marginales y pruebas de estabilidad.

La inferencia principal utiliza errores estándar agrupados por país. Los
resultados describen asociaciones condicionadas y no identifican efectos
causales.

El núcleo principal utiliza RENTS totales en M1, M2 y M3. Los archivos 06 y 07
replican M1 y M2 con RENTS_OIL_GAS y RENTS_MINING, respectivamente. El archivo
08 constituye el contraste desagregado formal que incorpora ambos componentes
conjuntamente. El módulo temporal se conserva como robustez complementaria y la
descomposición within-between permanece aplazada.

## Insumo común

Ambos peers leen el panel maestro:

```text
data/processed/00_master_panel/master_panel_country_year.dta
```

Ningún script econométrico modifica este archivo.

## Ejecución

Cada implementación puede ejecutarse desde PowerShell mediante su lanzador:

```powershell
.\scripts\econometrics\stata-peer-1\twfe\run_stata_peer_1.cmd -Stage all
.\scripts\econometrics\stata-peer-2\01_twfe_main\run_stata_peer_2.cmd -Stage core
```

En Peer 2, `-Stage core` ejecuta 01--05; `-Stage extensions`, 06--07;
`-Stage formal`, 08; y `-Stage all`, los ocho archivos en orden. También puede
ejecutarse cada etapa individualmente. Los logs automáticos del modo batch se
guardan dentro de la ruta de outputs correspondiente, nunca en la raíz del
repositorio.

## Estructura de outputs

Las salidas siguen la misma separación por estrategia econométrica:

```text
outputs/econometrics/
  stata-peer-1/
    gmm/
    iv/
    twfe/
  stata-peer-2/
    01_twfe_main/
    02_temporal_fe/
    03_within_between/
```

En Peer 2, Git conserva las tablas, figuras y manifiestos reproducibles de
`01_twfe_main/` y `02_temporal_fe/`. `03_within_between/` solo conserva su
marcador mientras el módulo permanezca aplazado.

Se excluyen del repositorio:

- `logs/`;
- `ado/`;
- archivos `.log`;
- bases derivadas `.dta`;
- estados de estimación `.ster`.

Los detalles metodológicos, controles y resultados de cada implementación se
documentan en:

- [`stata-peer-1/twfe/WORK_PLAN.md`](stata-peer-1/twfe/WORK_PLAN.md);
- [`stata-peer-2/ECONOMETRIC_STRATEGY.md`](stata-peer-2/ECONOMETRIC_STRATEGY.md);
- [`stata-peer-2/01_twfe_main/WORK_PLAN.md`](stata-peer-2/01_twfe_main/WORK_PLAN.md);
- [`stata-peer-2/02_temporal_fe/WORK_PLAN.md`](stata-peer-2/02_temporal_fe/WORK_PLAN.md);
- [`stata-peer-2/03_within_between/WORK_PLAN.md`](stata-peer-2/03_within_between/WORK_PLAN.md).
