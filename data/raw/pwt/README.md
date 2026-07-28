# Penn World Table 11.0

`pwt110.dta` es el archivo oficial compartido de Penn World Table 11.0. Se
almacena una sola vez porque contiene:

- `hc`, utilizado para construir HUMCAP;
- `pl_gdpo`, utilizado para construir `RER = log(pl_gdpo)`.

`pwt110_download_manifest.csv` registra la versión, el enlace oficial, el tamaño
del archivo y la fecha de descarga. El archivo puede reproducirse ejecutando
[`scripts/data/raw/pwt/pwt11_raw.R`](../../../scripts/data/raw/pwt/pwt11_raw.R).
