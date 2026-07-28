# Capa raw de datos

Esta carpeta conserva los insumos originales o casi originales utilizados para
construir las variables de la tesis. Ninguna imputación, logaritmo, tasa per
cápita ni índice propio debe aplicarse en esta capa.

Las fuentes compartidas se almacenan una sola vez:

- `atlas/`: comercio bilateral por producto SITC Rev. 2 para DRES, HHI, DIVX,
  PEXP y FEXP;
- `eci/`: captura país-año del ECI obtenida mediante la API GraphQL oficial del
  mismo Atlas;
- `world_bank_wdi/`: descarga conjunta de indicadores WDI utilizados por varias
  variables;
- `pwt/`: Penn World Table 11.0 para HUMCAP y RER.

Las demás carpetas identifican variables o bloques del modelo y pueden contener
extractos raw, archivos de cobertura o fuentes exclusivas. Los datos de gran
tamaño no se versionan en Git; los scripts bajo `scripts/data/raw/` permiten
volver a descargarlos o prepararlos.

Cada variable del modelo tiene una única definición y una única fuente activa.
`_archive_unused_sources/` conserva de forma recuperable materiales históricos
o fuentes descartadas; ningún script ni modelo debe leer esa carpeta.

El estado detallado de cada variable se encuentra en
[`data/DATA_INVENTORY.md`](../DATA_INVENTORY.md).
