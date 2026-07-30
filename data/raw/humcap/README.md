# Insumos raw de HUMCAP

## Fuente activa: PNUD, Human Development Report 2025

La fuente activa es la serie de años promedio de escolaridad (`mys`) para
adultos de 25 años o más publicada por el Programa de las Naciones Unidas para
el Desarrollo. El script descarga de forma reproducible la base completa y sus
metadatos oficiales, conserva ambos archivos originales y extrae una cuadrícula
sin transformar para los 55 países de la muestra.

Los archivos activos se almacenan en `undp_hdr/`:

- `source_files/HDR25_Composite_indices_complete_time_series.csv`: captura
  oficial completa;
- `source_files/HDR25_Composite_indices_metadata.xlsx`: metadatos oficiales;
- `humcap_undp_mys_input_1990_2023.csv`: años promedio de escolaridad en formato
  largo para los 55 países;
- `humcap_undp_metadata.csv`: definición y metadatos del indicador;
- `humcap_pwt11_reference_1996_2021.csv`: extracto mínimo de `hc` de PWT 11.0
  utilizado únicamente para contraste;
- `download_manifest.csv`: URLs, fechas, tamaños y hashes de la descarga.

La capa raw no calcula HUMCAP ni completa observaciones. La transformación de
los años de escolaridad se realiza únicamente en `data/processed/humcap/`.

## Cobertura de la fuente activa

En 1996--2021 hay 1.403 valores disponibles de 1.430 (98,11 %). Los 55 países
tienen al menos una observación; 49 presentan cobertura completa y seis
cobertura parcial. Los 27 faltantes corresponden a Angola (1996--1998),
Antigua y Barbuda, Nauru, Omán y Seychelles (1996--1999), y Surinam
(1996--2003).

## Fuentes de contraste y archivo

La serie `hc` de PWT 11.0 dejó de ser la definición activa de HUMCAP. Los cinco
extractos específicos que ya no alimentan ningún procesamiento fueron movidos
a `data/raw/_archive_unused_sources/humcap_pwt11_specific_extract/`. La base
compartida `data/raw/pwt/pwt110.dta` permanece activa porque sigue siendo el
insumo de RER y permite validar HUMCAP frente a PWT; no se mezcla con la serie
del PNUD.

El script activo es
[`scripts/data/raw/humcap/humcap_undp_raw.py`](../../../scripts/data/raw/humcap/humcap_undp_raw.py).

La construcción definitiva y sus diagnósticos están documentados en
[`data/processed/humcap/`](../../processed/humcap/).
