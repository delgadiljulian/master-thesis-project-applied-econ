# Insumos raw de PEXP y FEXP

`PEXP` y `FEXP` utilizan la fuente comercial compartida del Atlas of Economic
Complexity almacenada en `data/raw/atlas/sitc_rev2_trade/`. Los 233 archivos
por país, el catálogo de productos SITC Rev. 2 y los diagnósticos de cobertura
se conservan una sola vez; no deben copiarse dentro de esta carpeta.

Las categorías adoptadas son mutuamente excluyentes:

- `PEXP`: productos primarios no energéticos de las secciones SITC Rev. 2
  `0`, `1`, `2` y `4`, más la división `68`;
- `FEXP`: combustibles de la sección SITC Rev. 2 `3`.

Para ambas variables, el denominador es el valor total de las exportaciones de
mercancías. Incluye el residuo no clasificable `XXXX` para conservar el total
comercial observado y excluye las cinco categorías de servicios. `XXXX` no
forma parte de ninguno de los numeradores y se mantiene como diagnóstico de
cobertura.

La capa raw no calcula participaciones ni genera paneles derivados. `PEXP` y
`FEXP` se construyen conjuntamente en `data/processed/pexp_fexp/`. En el modelo
con `ECI`, `HHI`, `PEXP` y `FEXP` permanecen dentro del canal estructural;
cuando `DIVX = 1 - HHI` es la variable dependiente, se excluye únicamente
`HHI`.

El script procesado conjunto es
[`scripts/data/processed/pexp_fexp/pexp_fexp_processed.R`](../../../scripts/data/processed/pexp_fexp/pexp_fexp_processed.R).
