# Glosario de variables

Guía rápida para recordar qué significa cada abreviatura del panel y dónde buscar sus datos.

| Abreviatura | Nombre de la variable | Qué mide | Carpeta principal |
| --- | --- | --- | --- |
| `DRES` | Dependencia externa de recursos naturales | Participación de exportaciones de recursos naturales en exportaciones totales. Se usa para seleccionar la muestra, especialmente con el promedio 1990-1995. | `data/raw/00_sample_selection_dres/`, `data/processed/dres/` |
| `ECI` | Economic Complexity Index | Complejidad económica de la canasta exportadora. Es la variable dependiente principal. | `data/raw/eci/`, `data/processed/eci/` |
| `HHI` | Herfindahl-Hirschman Index | Concentración de la canasta exportadora. Valores altos indican mayor concentración. | `data/raw/hhi_divx/`, `data/processed/hhi_divx/` |
| `DIVX` | Diversificación exportadora | Complemento del HHI: `DIVX = 1 - HHI`. Valores altos indican mayor diversificación. | `data/raw/hhi_divx/`, `data/processed/hhi_divx/` |
| `RENTS` | Rentas de recursos naturales | Rentas totales de recursos naturales como porcentaje del PIB. Es la variable explicativa principal. | `data/raw/rents/`, `data/processed/rents/` |
| `INST` | Calidad institucional | Índice institucional construido con indicadores WGI como estado de derecho, control de corrupción y efectividad gubernamental. | `data/raw/inst/`, `data/processed/inst/` |
| `RENTS x INST` | Interacción rentas-instituciones | Evalúa si la calidad institucional modifica el efecto de las rentas extractivas. | Se construye dentro del panel |
| `OILPC` | Renta petrolera per cápita | Renta o abundancia petrolera por habitante. | `data/raw/oilpc_gaspc_coalpc/`, `data/processed/oilpc_gaspc_coalpc/` |
| `GASPC` | Renta gasífera per cápita | Renta o abundancia de gas natural por habitante. | `data/raw/oilpc_gaspc_coalpc/`, `data/processed/oilpc_gaspc_coalpc/` |
| `COALPC` | Renta carbonífera per cápita | Renta o abundancia de carbón por habitante. | `data/raw/oilpc_gaspc_coalpc/`, `data/processed/oilpc_gaspc_coalpc/` |
| `PEXP` | Exportaciones primarias | Participación de productos primarios en exportaciones totales. | `data/raw/pexp_fexp/`, `data/processed/pexp_fexp/` |
| `FEXP` | Exportaciones de combustibles | Participación de combustibles en exportaciones totales. | `data/raw/pexp_fexp/`, `data/processed/pexp_fexp/` |
| `VOL` | Volatilidad de commodities | Volatilidad de precios internacionales de commodities o términos de intercambio. | `data/raw/vol/`, `data/processed/vol/` |
| `RER` | Tipo de cambio real | Índice de tipo de cambio real; proxy de competitividad externa y enfermedad holandesa. | `data/raw/rer/`, `data/processed/rer/` |
| `HUMCAP` | Capital humano | Capital humano o escolaridad; proxy de capacidades productivas acumuladas. | `data/raw/humcap/`, `data/processed/humcap/` |
| `INNOV` | Innovación | Patentes, I+D u otra proxy de capacidades tecnológicas. | `data/raw/innov/`, `data/processed/innov/` |
| `NET` | Conectividad digital | Usuarios de internet o indicador equivalente de infraestructura digital. | `data/raw/net/`, `data/processed/net/` |
| `GDPPC` | PIB per cápita | Producto Interno Bruto per cápita. En el modelo se usa como `LOG_GDPPC`. | `data/raw/gdppc/`, `data/processed/gdppc/` |
| `LOG_GDPPC` | Logaritmo del PIB per cápita | Proxy del nivel de desarrollo económico. | `data/raw/gdppc/`, `data/processed/gdppc/` |
| `FISC` | Canal fiscal | Capacidad fiscal, gasto público o proxy de prociclicidad fiscal. | `data/raw/fisc/`, `data/processed/fisc/` |
| `FIN` | Desarrollo financiero | Crédito doméstico al sector privado como porcentaje del PIB. | `data/raw/fin/`, `data/processed/fin/` |

## Convención de carpetas

- `data/raw/`: insumos originales o casi originales, organizados por variable.
- `data/processed/`: datos limpios, transformados o listos para unirse al panel, organizados por variable.
- `data/processed/00_master_panel/`: paneles integrados país-año.
