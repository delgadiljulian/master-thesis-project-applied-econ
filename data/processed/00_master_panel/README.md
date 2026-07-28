# Panel maestro

Esta carpeta contiene un único panel país-año para los 55 países seleccionados
mediante `DRES >= 20 %` y el período 1996-2021. Los archivos
`master_panel_country_year.csv` y `master_panel_country_year.dta` representan
exactamente el mismo panel en dos formatos.

## Etapa actual

El panel integra:

- los identificadores de país y año;
- el promedio DRES de 1990-1995 utilizado para fijar la muestra;
- `RENTS`, `RENTS_OIL_GAS` y `RENTS_MINING`;
- `INST`;
- `RENTS_X_INST`, calculada como el producto directo:

```text
RENTS_X_INST = RENTS * INST
```

- `OILPC`, `GASPC` y `COALPC`, conservadas en dólares constantes por habitante
  y sin transformaciones adicionales.
- `PEXP` y `FEXP`, conservadas como porcentajes separados de las exportaciones
  de mercancías.
- `VOL`, conservada como la desviación estándar móvil de cinco variaciones
  porcentuales logarítmicas del índice CTOT.
- `RER`, definida como `log(pl_gdpo)` de PWT 11.0.
- `HUMCAP`, definida como el índice `hc` de PWT 11.0 en sus niveles
  publicados.
- `INNOV`, definida como `log(1 + artículos científicos y técnicos por millón
  de habitantes)`.
- `NET`, definida como personas que utilizan internet en porcentaje de la
  población.
- `LOG_GDPPC`, definida como el logaritmo natural del PIB per cápita en PPA
  constante.
- `GOVCONS`, definida como gasto de consumo final del gobierno general en
  porcentaje del PIB.
- `FIN`, definida como crédito doméstico al sector privado en porcentaje del
  PIB.
- `ECI`, variable dependiente principal, tomada del campo `countryYear.eci` de
  la API oficial del Atlas.
- `HHI`, concentración de las exportaciones de mercancías clasificadas;
- `DIVX`, resultado complementario definido como `1 - HHI`.

La interacción solo se calcula cuando `RENTS` e `INST` están observadas en el
mismo país-año. No se sustituyen faltantes por cero, no se interpola y no se
centran los componentes antes de multiplicarlos.

`OILPC`, `GASPC` y `COALPC` se incorporan mediante una unión uno-a-uno con sus
faltantes y ceros publicados intactos. No se aplican logaritmos, recortes ni
imputaciones durante el merge.

`PEXP` y `FEXP` también se integran uno a uno, sin sumarlas ni convertirlas en
categorías alternativas. Sus numeradores son mutuamente excluyentes y ambas
permanecen dentro del canal estructural definido por la tesis.

`VOL` se incorpora en su escala procesada, sin recalcular ventanas, recortar
valores ni completar observaciones faltantes.

`RER` se incorpora después de su transformación logarítmica en la capa
procesada. No se vuelve a transformar, combinar con otras fuentes ni imputar.

`HUMCAP` se incorpora directamente como índice; no se interpreta como años de
escolaridad y no recibe logaritmos, estandarización ni imputación.

`INNOV` se incorpora después de su transformación en la capa procesada. No se
mezcla con patentes ni otros indicadores y conserva como válidos sus valores
iguales a cero.

`NET` se incorpora en su escala porcentual 0–100, sin logaritmos,
estandarización, interpolación ni imputación.

`LOG_GDPPC` se incorpora después de su transformación en la capa procesada. No
se utiliza el nivel ni una medida de PIB per cápita sin ajuste por PPA.

`GOVCONS` se incorpora después del control de calidad aplicado en processed.
No se interpreta como presión tributaria ni capacidad fiscal, y no recupera la
definición descartada `FISC`.

`FIN` se incorpora en su escala porcentual publicada, sin logaritmos,
estandarización, interpolación, imputación ni recorte.

`ECI` se incorpora bajo el nombre `eci` para 1996–2021. La serie completa
procede de una única captura de la API oficial del Atlas: no se rellenan
faltantes con otra fuente ni se combinan valores de la antigua tabla de
rankings.

`HHI` y `DIVX` se incorporan desde el mismo panel comercial y se restringen
también a 1996–2021. El constructor verifica en cada observación que ambas
variables estén dentro de 0–1 y que `DIVX = 1 - HHI`.

La presencia conjunta de ambas variables en la base no implica que entren
simultáneamente en todas las regresiones. `HHI` se incluye únicamente cuando
`ECI` es la variable dependiente; se excluye cuando la dependiente es `DIVX`.

Los años 1997, 1999 y 2001 permanecen sin interacción porque WGI no publicó los
insumos de `INST`. Las demás variables procesadas se incorporarán
incrementalmente sin cambiar la cuadrícula maestra.

## Cobertura validada

`RENTS_X_INST` está disponible en 1.197 de las 1.430 observaciones potenciales
(83,71 %). Si se consideran únicamente los 23 años publicados por WGI, la
cobertura es de 1.197 sobre 1.265 país-años (94,62 %).

Los 165 país-años correspondientes a 1997, 1999 y 2001 explican la mayor parte
de los faltantes. Otros 68 país-años no tienen simultáneamente `RENTS` e
`INST`. La interacción tiene al menos una observación en 53 países; Sierra
Leona y Nauru no tienen ninguna porque carecen de la medida agregada `RENTS`.

La cobertura es de 1.397 país-años para `OILPC` (97,69 %), 1.365 para `GASPC`
(95,45 %) y 1.384 para `COALPC` (96,78 %). Los tres indicadores están
simultáneamente disponibles en 1.352 país-años.

`PEXP` y `FEXP` tienen cobertura completa: 1.430 país-años y 55 países en cada
variable. Ambas permanecen dentro del rango 0–100 y su suma no supera 100 en
ninguna observación.

`VOL` está disponible en 1.403 país-años (98,11 %). Nauru no tiene
observaciones y Rusia conserva como faltante únicamente 1996.

`RER` está disponible en 1.352 país-años (94,55 %). Libia, Nauru y Papúa Nueva
Guinea conservan sus 78 observaciones como faltantes.

`HUMCAP` está disponible en 1.222 país-años (85,45 %). Los ocho países sin
observaciones de PWT conservan sus 208 país-años como faltantes; los otros 47
países tienen cobertura completa.

`INNOV` tiene cobertura completa en las 1.430 observaciones. Quince país-años
con cero artículos conservan `INNOV = 0`.

`NET` está disponible en 1.379 país-años (96,43 %). Los 51 faltantes y los tres
ceros publicados se conservan intactos; todos los países tienen al menos una
observación.

`LOG_GDPPC` está disponible en 1.378 país-años (96,36 %). Venezuela y Yemen
conservan como faltantes sus 52 país-años; los otros 53 países tienen cobertura
completa.

`GOVCONS` está disponible en 1.152 país-años (80,56 %). Los 278 faltantes
incluyen los 16 ceros anómalos de Venezuela marcados previamente como no
utilizables; no se imputan ni reemplazan.

`FIN` está disponible en 1.202 país-años (84,06 %). Nauru no tiene
observaciones. Las 84 observaciones superiores a 100 % se conservan como
valores económicamente admisibles.

`ECI` tiene cobertura completa en las 1.430 observaciones: los 55 países
disponen de 26 años entre 1996 y 2021. No existen valores faltantes, llaves
duplicadas ni valores infinitos en esta variable.

`HHI` y `DIVX` tienen cobertura completa en las 1.430 observaciones del panel.
La identidad entre ambas se cumple dentro de la tolerancia numérica.

## Archivos

- `master_panel_country_year.csv` y `master_panel_country_year.dta`: única base
  maestra en formatos equivalentes;
- `master_panel_country_coverage_1996_2021.csv`: cobertura por país de las
  variables integradas;
- `master_panel_year_coverage_1996_2021.csv`: cobertura anual y años
  estructuralmente ausentes de WGI;
- `master_panel_validation_summary.csv`: dimensiones, llaves, cobertura,
  fórmula y equivalencia entre formatos.

El script reproducible es
[`scripts/panel/build_master_panel.R`](../../../scripts/panel/build_master_panel.R).
