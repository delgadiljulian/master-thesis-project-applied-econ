# Fuente compartida World Development Indicators

Esta carpeta contiene una descarga conjunta de 17 indicadores WDI para
1980-2022. Los ZIP originales se conservan bajo `source_zips/` y el panel
país-año combinado se guarda como `wdi_thesis_inputs_1980_2022.csv`.

La descarga incluye insumos para rentas extractivas, abundancia por habitante,
PIB per cápita, finanzas, fiscalidad, innovación, conectividad, capital humano y
la robustez de RER. No incluye rentas forestales ni el indicador de rentas
naturales totales: `RENTS` utiliza exclusivamente petróleo, gas natural, carbón
y minerales.

`wdi_thesis_download_manifest.csv` documenta los códigos oficiales, propósitos,
archivos fuente y conteos disponibles. La descarga se reproduce con
[`scripts/data/world_bank_wdi/wdi_thesis_inputs.R`](../../../scripts/data/world_bank_wdi/wdi_thesis_inputs.R).
