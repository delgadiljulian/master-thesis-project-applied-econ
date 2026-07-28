# Construcción del panel maestro

El constructor integra una única definición aprobada por variable y produce un
solo panel lógico en formatos CSV y Stata. A partir de ese mismo panel se
estimarán:

1. modelo principal con `ECI`;
2. modelo complementario con `DIVX = 1 - HHI`, excluyendo solamente `HHI`.

La etapa actual parte de la cuadrícula fija `DRES >= 20 %` e integra `RENTS`,
sus dos desagregaciones sectoriales, `INST`, `OILPC`, `GASPC` y `COALPC`.
También integra `PEXP`, `FEXP`, `VOL`, `RER`, `HUMCAP`, `INNOV` y `NET`, y
los controles `LOG_GDPPC`, `GOVCONS` y `FIN`. La variable dependiente principal
`ECI`, `HHI` y `DIVX` también forman parte del panel. El constructor genera
`rents_x_inst = rents * inst` únicamente cuando ambos componentes están
observados y verifica la identidad `divx = 1 - hhi`.

El script reproducible es `build_master_panel.R`. Las salidas oficiales se
guardan en `data/processed/00_master_panel/`; solo existe un
`master_panel_country_year` representado en dos formatos equivalentes.
