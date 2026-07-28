# DRES: dependencia externa de recursos no renovables del subsuelo

Esta carpeta conserva los insumos auxiliares utilizados para validar la variable
de selección muestral:

```text
DRES_it = Xres_it / X_it
```

donde:

- `Xres_it`: exportaciones de combustibles minerales, minerales crudos,
  minerales metalíferos, metales no ferrosos, piedras preciosas y oro no
  monetario del país `i` en el año `t`;
- `X_it`: exportaciones totales de bienes del país `i` en el año `t`.

La definición excluye productos agrícolas, forestales, pesqueros y los demás
recursos naturales renovables.

## Fuente principal: Atlas of Economic Complexity

DRES se construye con las exportaciones Atlas SITC Revisión 2 a cuatro dígitos
almacenadas en `data/raw/atlas/sitc_rev2_trade/country_exports/`. Esta fuente se
comparte con HHI, DIVX, PEXP y FEXP para evitar descargas y copias duplicadas.

El numerador extractivo incorpora:

| Grupo SITC | Contenido |
| --- | --- |
| `3` | Combustibles minerales, lubricantes y materiales relacionados |
| `27` | Minerales crudos; se excluye `2711`, de origen animal o vegetal |
| `28` | Minerales metalíferos y chatarra |
| `68` | Metales no ferrosos |
| `6672` y `6673` | Diamantes y piedras preciosas naturales; se excluyen perlas y piedras sintéticas |
| `971` | Oro no monetario |

El promedio nacional se calcula únicamente cuando existen exportaciones
positivas en cada uno de los seis años de 1990 a 1995. La selección se limita al
ámbito nacional del estudio y excluye territorios dependientes, regiones
administrativas especiales, entidades históricas disueltas y códigos sin un
país identificable.

Los antiguos criterios de población superior a un millón y exportaciones
superiores a USD 1.000 millones se conservan como diagnósticos descriptivos,
pero no excluyen países de la muestra.

## Muestras construidas

El script
[`scripts/data/processed/dres/dres_processed.R`](../../../scripts/data/processed/dres/dres_processed.R)
genera una única muestra:

| Umbral del promedio DRES 1990--1995 | Uso | Países |
| --- | --- | ---: |
| 20 % | Muestra del modelo | 55 |

Las cifras se calculan directamente desde los archivos raw y no corresponden a
estimaciones introducidas manualmente.

## Salidas procesadas

El procesamiento escribe en `data/processed/dres/`:

- `dres_country_year_1990_1995.csv`: numerador, denominador, componentes y DRES
  por país-año;
- `dres_country_profile_1990_1995.csv`: promedio nacional, cobertura, ámbito y
  bandera de muestra y diagnósticos descriptivos;
- `dres_sitc_product_scope.csv`: catálogo exacto de productos incluidos;
- `dres_sample_20.csv`: lista única de países del modelo;
- `dres_selection_summary.csv`: conteos utilizados en el diagrama metodológico.

No se identificaron correcciones negativas dentro de las exportaciones de
mercancías utilizadas. Las diez filas negativas detectadas corresponden a
categorías de servicios y quedan excluidas tanto del numerador como del
denominador de DRES.

## WDI como validación

`world_bank_wdi/` conserva los indicadores de combustibles, minerales y
metales, exportaciones totales y población descargados del Banco Mundial. No se
utilizan como fuente final de DRES porque la cobertura comercial de 1990--1995
es insuficiente. En las 496 observaciones comparables, el DRES Atlas y la suma
de las participaciones WDI presentan una correlación de 0,95 y una diferencia
absoluta mediana de 1,93 puntos porcentuales.

La disponibilidad de PIB y de las demás variables econométricas se evaluará al
construir el panel. No modifica retrospectivamente la clasificación DRES.
