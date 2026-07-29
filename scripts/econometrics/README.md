# Econometría

Esta carpeta contiene la primera etapa del análisis econométrico del TFM:
los modelos agregados de rentas extractivas del subsuelo (`RENTS`) para
complejidad económica (`ECI`) y diversificación exportadora (`DIVX`).

El análisis fue desarrollado y contrastado mediante dos implementaciones
independientes en Stata:

```text
scripts/econometrics/
  stata-peer-1/
    01_data_prep_and_diagnostics.do
    02_models_and_exports.do
    run_stata_peer_1.cmd
    run_stata_peer_1.ps1
    WORK_PLAN.md
  stata-peer-2/
    01_data_preparation_diagnostics.do
    02_econometric_models.do
    run_stata_peer_2.cmd
    run_stata_peer_2.ps1
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

La futura desagregación entre hidrocarburos y minería no forma parte de estos
archivos. Se desarrollará posteriormente en un `.do` separado.

## Insumo común

Ambos peers leen el panel maestro:

```text
data/processed/00_master_panel/master_panel_country_year.dta
```

Ningún script econométrico modifica este archivo.

## Ejecución

Cada implementación puede ejecutarse desde PowerShell mediante su lanzador:

```powershell
.\scripts\econometrics\stata-peer-1\run_stata_peer_1.cmd -Stage all
.\scripts\econometrics\stata-peer-2\run_stata_peer_2.cmd -Stage all
```

Los lanzadores ejecutan primero la preparación y los diagnósticos y después
los modelos. Los logs automáticos del modo batch se guardan dentro de la ruta
de outputs correspondiente, nunca en la raíz del repositorio.

## Outputs versionados

Git conserva los resultados reproducibles de las secciones:

```text
outputs/econometrics/stata-peer-1/00_design/ ... 05_stability/
outputs/econometrics/stata-peer-2/00_design/ ... 05_stability/
```

Se excluyen del repositorio:

- `06_final/`;
- `logs/`;
- `ado/`;
- bases derivadas `.dta`;
- estados de estimación `.ster`.

Los detalles metodológicos, controles y resultados de cada implementación se
documentan en:

- [`stata-peer-1/WORK_PLAN.md`](stata-peer-1/WORK_PLAN.md);
- [`stata-peer-2/WORK_PLAN.md`](stata-peer-2/WORK_PLAN.md).
