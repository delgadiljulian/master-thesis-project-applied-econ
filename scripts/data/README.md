# Jerarquía de scripts de datos

La carpeta `scripts/data/` separa físicamente las dos capas del flujo:

```text
scripts/data/
├── raw/
└── processed/
```

No deben existir constructores de variables directamente en `scripts/data/`.

## `raw/`

Contiene exclusivamente scripts de descarga, importación y preparación de
insumos sin transformar. Sus nombres terminan en `_raw.R` o `_raw.py`.

Estos scripts:

- escriben solamente en `data/raw/`;
- conservan los valores publicados y sus faltantes;
- no aplican logaritmos, índices propios, sumas entre indicadores ni medidas
  per cápita;
- pueden leer la lista fija DRES únicamente para producir diagnósticos de
  cobertura, pero no escriben en `data/processed/`.

## `processed/`

Contiene los scripts que construyen las variables definitivas. Sus nombres
terminan en `_processed.R` o `_processed.py`.

Estos scripts:

- leen insumos desde `data/raw/`;
- pueden leer la muestra fija desde `data/processed/dres/`;
- aplican únicamente las fórmulas aprobadas en el TFM;
- escriben en la carpeta correspondiente de `data/processed/`;
- generan archivos CSV y Stata equivalentes, además de diagnósticos de
  cobertura y validación.

## Encabezado obligatorio

Cada script debe declarar al comienzo:

```text
CAPA
VARIABLE o FUENTE
ENTRADAS
SALIDAS
```

Los scripts de figuras y análisis descriptivo se almacenan en
`scripts/analysis/`, no en `scripts/data/`.
