# Fuente compartida World Development Indicators

Esta carpeta contiene una descarga conjunta de 11 indicadores WDI para
1980-2022. Los ZIP originales se conservan bajo `source_zips/` y el panel
país-año combinado se guarda como `wdi_thesis_inputs_1980_2022.csv`.

La descarga incluye insumos para rentas extractivas, abundancia por habitante,
PIB per cápita, finanzas, consumo gubernamental, innovación y conectividad. No
incluye indicadores alternativos de capital humano, innovación, fiscalidad ni
tipo de cambio real. Tampoco incluye rentas forestales ni el indicador de rentas
naturales totales: `RENTS` utiliza exclusivamente petróleo, gas natural, carbón
y minerales.

`wdi_thesis_download_manifest.csv` documenta los códigos oficiales, propósitos,
archivos fuente y conteos disponibles. La descarga se reproduce con
[`scripts/data/raw/world_bank_wdi/wdi_thesis_inputs_raw.R`](../../../scripts/data/raw/world_bank_wdi/wdi_thesis_inputs_raw.R).
