# Fuente compartida Atlas SITC Rev. 2

`sitc_rev2_trade/` contiene la descarga comercial por país, año y producto del
Atlas of Economic Complexity. La fuente se almacena una sola vez y alimenta las
construcciones de DRES, HHI, DIVX, PEXP y FEXP.

Los archivos originales por país permanecen en `country_exports/`; catálogos,
manifiestos y diagnósticos de cobertura permanecen junto a ellos. El descargador
reproducible es
[`scripts/data/atlas/atlas_sitc_trade_data.R`](../../../scripts/data/atlas/atlas_sitc_trade_data.R).
