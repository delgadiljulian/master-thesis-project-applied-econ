# Glosario de variables

Guía rápida para recordar qué significa cada abreviatura del panel y dónde buscar sus datos.

| Abreviatura | Nombre de la variable | Qué mide | Carpeta principal |
| --- | --- | --- | --- |
| `DRES` | Dependencia externa de recursos no renovables del subsuelo | Participación de combustibles minerales, minerales, metales, piedras preciosas naturales y oro no monetario en las exportaciones de mercancías. El promedio 1990-1995 selecciona muestras anidadas de 55, 49 y 42 países con umbrales de 20%, 30% y 40%. | `data/raw/atlas/sitc_rev2_trade/`, `data/processed/dres/` |
| `ECI` | Economic Complexity Index | Complejidad económica de la canasta exportadora. Es la variable dependiente principal. | `data/raw/eci/`, `data/processed/eci/` |
| `HHI` | Herfindahl-Hirschman Index | Concentración de las exportaciones de mercancías entre productos SITC Rev. 2 de cuatro dígitos. Los servicios y el residuo no clasificable `XXXX` no se tratan como productos; la participación de `XXXX` se conserva como diagnóstico de cobertura. Valores altos indican mayor concentración. | `data/raw/atlas/sitc_rev2_trade/`, `data/processed/hhi_divx/` |
| `DIVX` | Diversificación exportadora | Complemento exacto del HHI: `DIVX = 1 - HHI`. Valores altos indican mayor diversificación entre productos SITC clasificados. | `data/raw/atlas/sitc_rev2_trade/`, `data/processed/hhi_divx/` |
| `RENTS` | Rentas extractivas del subsuelo | Suma de las rentas de petróleo, gas natural, carbón y minerales como porcentaje del PIB. Excluye bosques y cualquier componente agrícola o renovable. Es la variable explicativa principal. | `data/raw/world_bank_wdi/`, `data/processed/rents/` |
| `INST` | Calidad institucional | Índice institucional construido con indicadores WGI como estado de derecho, control de corrupción y efectividad gubernamental. | `data/raw/inst/`, `data/processed/inst/` |
| `RENTS x INST` | Interacción rentas-instituciones | Evalúa si la calidad institucional modifica el efecto de las rentas extractivas. | Se construye dentro del panel |
| `OILPC` | Renta petrolera per cápita | Renta o abundancia petrolera por habitante. | `data/raw/oilpc_gaspc_coalpc/`, `data/processed/oilpc_gaspc_coalpc/` |
| `GASPC` | Renta gasífera per cápita | Renta o abundancia de gas natural por habitante. | `data/raw/oilpc_gaspc_coalpc/`, `data/processed/oilpc_gaspc_coalpc/` |
| `COALPC` | Renta carbonífera per cápita | Renta o abundancia de carbón por habitante. | `data/raw/oilpc_gaspc_coalpc/`, `data/processed/oilpc_gaspc_coalpc/` |
| `PEXP` | Exportaciones primarias | Participación de productos primarios en exportaciones de mercancías. | `data/raw/atlas/sitc_rev2_trade/`, `data/processed/pexp_fexp/` |
| `FEXP` | Exportaciones de combustibles | Participación de combustibles en exportaciones de mercancías. | `data/raw/atlas/sitc_rev2_trade/`, `data/processed/pexp_fexp/` |
| `VOL` | Volatilidad de commodities | Volatilidad de precios internacionales de commodities o términos de intercambio. | `data/raw/vol/`, `data/processed/vol/` |
| `RER` | Tipo de cambio real | Medida principal: `log(pl_gdpo)` de PWT 11.0, donde un aumento representa una apreciación real. El REER del Banco Mundial/FMI se conserva como robustez. | `data/raw/pwt/`, `data/raw/rer/pwt_wdi/`, `data/processed/rer/` |
| `HUMCAP` | Capital humano | Capital humano o escolaridad; proxy de capacidades productivas acumuladas. | `data/raw/humcap/`, `data/processed/humcap/` |
| `INNOV` | Capacidades científico-tecnológicas | Medida principal: `log(1 + artículos científicos y técnicos por millón de habitantes)`. Las patentes de residentes por millón se conservan como robustez. | `data/raw/innov/world_bank_wdi/`, `data/processed/innov/` |
| `NET` | Conectividad digital | Usuarios de internet o indicador equivalente de infraestructura digital. | `data/raw/net/`, `data/processed/net/` |
| `GDPPC` | PIB per cápita | Producto Interno Bruto per cápita. En el modelo se usa como `LOG_GDPPC`. | `data/raw/gdppc/`, `data/processed/gdppc/` |
| `LOG_GDPPC` | Logaritmo del PIB per cápita | Proxy del nivel de desarrollo económico. | `data/raw/gdppc/`, `data/processed/gdppc/` |
| `FISC` | Canal fiscal | Capacidad fiscal, gasto público o proxy de prociclicidad fiscal. | `data/raw/fisc/`, `data/processed/fisc/` |
| `FIN` | Desarrollo financiero | Crédito doméstico al sector privado como porcentaje del PIB. | `data/raw/fin/`, `data/processed/fin/` |

## Convención de carpetas

- `data/raw/`: insumos originales o casi originales. Se organizan por variable cuando la fuente es específica y por fuente cuando un mismo insumo, como el Atlas, alimenta varias variables.
- `data/processed/`: datos limpios, transformados o listos para unirse al panel, organizados por variable.
- `data/processed/00_master_panel/`: paneles integrados país-año.
