# Penn World Table 11.0

`pwt110.dta` es el archivo oficial compartido de Penn World Table 11.0. Se
almacena una sola vez porque contiene:

- `pl_gdpo`, utilizado para construir `RER = log(pl_gdpo)`;
- `hc`, conservado únicamente para contrastar la construcción activa de
  HUMCAP basada en años promedio de escolaridad del PNUD.

La serie `hc` no se mezcla con HUMCAP ni se utiliza para completar sus vacíos.
La base compartida permanece activa porque `pl_gdpo` sigue siendo el insumo de
RER y `hc` es una referencia de validación.

`pwt110_download_manifest.csv` registra la versión, el enlace oficial, el tamaño
del archivo y la fecha de descarga. El archivo puede reproducirse ejecutando
[`scripts/data/raw/pwt/pwt11_raw.R`](../../../scripts/data/raw/pwt/pwt11_raw.R).
