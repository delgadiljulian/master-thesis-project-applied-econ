# ECI — Atlas of Economic Complexity

Esta carpeta conserva la captura raw del Índice de Complejidad Económica
utilizado por la tesis. La única fuente activa es el campo `countryYear.eci` de
la API GraphQL oficial del Atlas of Economic Complexity del Harvard Growth Lab.

El archivo `atlas/atlas_eci_country_year_1995_2022.csv` conserva los valores
publicados por la API sin redondeo, imputación, interpolación ni transformación.
`atlas/atlas_eci_api_metadata.csv` registra la fecha UTC de consulta, el
intervalo solicitado, los conteos de filas y el hash SHA-256 de la captura.

El Atlas permite explorar información de países y territorios que no
necesariamente cumplen los criterios utilizados para aparecer en sus perfiles
y rankings públicos. Por esa razón, la disponibilidad mediante API no se
restringe utilizando la antigua marca `in_rankings`. La limitación de los
rankings se documenta como una advertencia de calidad, pero no se convierte en
otra variable ni en una muestra econométrica adicional.

La captura se regenera con:

```text
python scripts/data/raw/eci/eci_atlas_api_raw.py
```

La antigua tabla `growth_proj_eci_rankings.csv` no forma parte del flujo activo:
excluía economías fuera del ranking y producía faltantes que no existían en la
consulta país-año de la API.
