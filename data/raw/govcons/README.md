# Insumos raw de GOVCONS

La fuente activa es la base *National Accounts Main Aggregates* de la División
de Estadística de Naciones Unidas. La captura utiliza la serie 16
(`GDP by Expenditure, Percentage Distribution (Shares)`) y su componente 3
(`General government final consumption expenditure`).

## Fuente activa: Naciones Unidas

`un_ama/govcons_un_ama_1970_2024.csv` contiene la serie porcentual para los 55
países de la muestra DRES. La captura conserva 2.986 país-años históricos y
cubre las 1.430 celdas requeridas entre 1996 y 2021.

`un_ama/govcons_un_ama_metadata.csv` conserva los metadatos país-específicos:
fuente, publicación, período y método de construcción. Estos campos permiten
distinguir valores directos, derivados y períodos con métodos superpuestos.

`un_ama/download_manifest.csv` registra la fecha UTC de consulta, la fecha de
actualización informada por la fuente, los endpoints, los conteos y los hashes
SHA-256 de las capturas.

La descarga se regenera con:

```text
python scripts/data/raw/govcons/govcons_un_ama_raw.py
```

## Referencia de contraste: WDI

El indicador `NE.CON.GOVT.ZS` utilizado anteriormente se consulta en la
descarga compartida `data/raw/world_bank_wdi/wdi_thesis_inputs_1980_2022.csv`.
WDI ya no define la variable activa y no se usa para rellenar selectivamente
la serie de Naciones Unidas. Se mantiene únicamente como referencia para la
comparación de 1.152 país-años comunes.

El antiguo extracto específico de GOVCONS, que duplicaba esa descarga
compartida, se conserva de forma recuperable en
`data/raw/_archive_unused_sources/govcons_world_bank_wdi/`. Ningún proceso
activo lee los archivos archivados.

Los 16 ceros publicados por WDI para Venezuela entre 1996 y 2011 permanecen en
raw. En la comparación se marcan como no utilizables, tal como ocurría en el
flujo anterior.

La variable activa y los diagnósticos comparativos se construyen en
[`data/processed/govcons/`](../../processed/govcons/).
