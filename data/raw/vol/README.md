# Insumos raw de VOL

## Fuente: IMF Commodity Terms of Trade

`imf_ctot/vol_ctot_input_1962_2022.csv` y su archivo equivalente para Stata
contienen la versión anual con ponderaciones fijas, en niveles, del `Commodity
Net Export Price Index` del FMI (`CEMPI_CTOTNX_TT`, `H_FW_IX`). Este índice pondera los precios
internacionales de commodities mediante la razón entre exportaciones netas y
comercio total de commodities de cada país.

Esta es la única serie activa para `VOL`. El raw no calcula variaciones
logarítmicas, desviaciones estándar ni ventanas móviles.

La construcción en `data/processed/vol/` es:

\[
g_{it}=100\left[\log(CTOT_{it})-\log(CTOT_{i,t-1})\right],
\]

\[
VOL_{it}=sd\left(g_{i,t-4},\ldots,g_{it}\right).
\]

Por tanto, `VOL` será la desviación estándar móvil de cinco años de las
variaciones porcentuales anuales del índice con ponderaciones fijas.

`imf_ctot/imf_ctot_api_source.csv` conserva la respuesta tabular del
[IMF Data API](https://api.imf.org/external/sdmx/3.0), mientras que
`imf_ctot/imf_ctot_download_manifest.csv` documenta la consulta, la versión del
flujo y las fechas de cobertura.

Para los 55 países de la muestra DRES durante 1996-2022, el índice raw
cubren 1.458 de 1.485 celdas país-año (98,2 %). Cincuenta y cuatro países son
completos y Nauru no tiene serie. Al exigir los seis niveles consecutivos
necesarios para calcular cinco variaciones anuales, la medida puede construirse
en 1.457 celdas (98,1 %) para 1996-2022: Rusia pierde 1996 y Nauru continúa sin
observaciones. El panel procesado de la tesis utiliza 1996-2021.

El script reproducible es
[`scripts/data/raw/vol/vol_imf_ctot_raw.R`](../../../scripts/data/raw/vol/vol_imf_ctot_raw.R).

La construcción definitiva se realiza mediante
[`scripts/data/processed/vol/vol_processed.R`](../../../scripts/data/processed/vol/vol_processed.R).
