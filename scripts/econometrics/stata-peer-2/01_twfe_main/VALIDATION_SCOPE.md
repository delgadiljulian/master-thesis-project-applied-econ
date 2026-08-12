# Alcance de las validaciones de Peer-2

Este documento separa las validaciones que protegen el contenido econométrico de
las verificaciones administrativas de reproducibilidad. Ninguna regla cambia
datos, estimaciones ni resultados; la clasificación sólo evita confundir una
inconsistencia de inventario con un problema metodológico.

## Controles esenciales: detienen la ejecución

- Integridad del panel: llave país-año, variables requeridas y ausencia de
  transformaciones o imputaciones no autorizadas.
- Contrato de muestra: observaciones, países y años efectivos preespecificados.
- Identidades y especificación: `DIVX = 1 - HHI`, exclusión de HHI de DIVX y
  presencia de los términos constitutivos de cada interacción.
- Estimación e inferencia: coincidencia entre `e(sample)` y la bandera de
  muestra, número de países y conglomerados, efectos fijos y método de
  inferencia aprobado. La regla principal es agrupación por país; una prueba
  residual no activa automáticamente un estimador alternativo.
- Productos analíticos necesarios para el TFM: tablas, coeficientes, pruebas
  conjuntas y sensibilidades que alimentan la interpretación.

## Controles administrativos: reportan, pero no redefinen el modelo

- Índices de archivos, manifiestos, conteos de exportaciones y metadatos de
  ejecución.
- Conteos de filas de archivos derivados, siempre que no sean el único medio
  para validar una restricción econométrica.
- Etiquetas históricas como "Control G" o "Control J". Son trazabilidad de la
  corrida, no evidencia econométrica adicional.

Los scripts usan `peer2_assert_estimation_contract` para los controles
esenciales que se repiten después de una estimación. Las verificaciones
administrativas se conservan como documentación del paquete, pero no justifican
agregar, retirar o reinterpretar especificaciones.
